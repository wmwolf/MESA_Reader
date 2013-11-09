# NAME: MESA_Reader
# AUTHOR: William Wolf
# LAST UPDATED: August 21, 2013
# PURPOSE: Provides access to the MESAData class, which, through the methods
#          header and data, can return a value (header) or DVector (data) the
#          corresponds to the key provided to it. New in this version: access
#          to MESAProfileIndex and MESALogDir classes, described where they
#          appear.

# EXAMPLES:
   # read in data from filename (either history or profile)
   # s = MESA_Data.new(filename)
   # s.header('version_number') # => version number of profile or model
   # s.data('log_Teff') # => Dvector containign log_Teff values from file
   #
   # s.data_at_model_number('log_Teff', 30) # => value of s.data('log_Teff')
   #  from the index i where s.data('model_number')[i] == 30
   #
   # s.header?('version_number')  # => true if 'version_number' is a header
   #  category, otherwise false
   #
   # s.data?('log_Teff') # => true if 'log_Teff' is a data category in file,
   #  otherwise false
   #
   # s.where('log_Teff', 'log_L', ...) { |t, l, ...| test(t, l, ...)} # =>
   #   array of indices for  values of s.data('log_Teff'), s.data('log_L'),
   #   etc. for which the test function returns true.
   #  Useful for selecting sub-vectors persuant to a test on another vector,
   #  like all luminosities past a certain age. You may specify an arbitrary
   #  number of key (data categories) so your test can be arbitrarily
   #  complicated. For instance, the example test could select points from a
   #  history file that correspond to a time when the stellar model was in a
   #  particular region of the HR diagram.

require 'Dobjects/Dvector' #gives access to DVectors

class MESAData
  attr_reader :file_name, :header_names, :header_data, :bulk_names, :bulk_data
  def initialize(file_name, scrub = true, dbg = false)
    # In this context, rows start at 1, not 0. These can and should be changed
    # if MESA conventions change.

    header_names_row = 2
    header_data_row = header_names_row + 1
    bulk_names_row = 6
    bulk_data_start_row = bulk_names_row + 1

    @file_name = file_name
    @header_names = read_one_line(@file_name, header_names_row).chomp.split
    @header_data = read_one_line(@file_name, header_data_row).chomp.split
    @header_hash = {}
    @header_names.each_index do |i|
      if @header_data[i].include?(".")
        new_entry = @header_data[i].to_f
      else
        new_entry = @header_data[i].to_i
      end
      @header_hash[@header_names[i]] = new_entry
    end
    @bulk_names = read_one_line(@file_name, bulk_names_row).chomp.split
    @bulk_data = Array.new(@bulk_names.size)
    0.upto(@bulk_names.length-1) do |i|
      @bulk_data[i] = Dobjects::Dvector.new
    end
    Dobjects::Dvector.read(file_name,@bulk_data,bulk_data_start_row)
    @data_hash = {}
    @bulk_names.each do |name|
      @data_hash[name] = @bulk_data[@bulk_names.index(name)]
    end
    remove_backups(dbg) if data?('model_number') if scrub
  end

  def header(key)
    if header?(key)
      @header_hash[key]
    else
      puts "WARNING: Couldn't find header #{key} in #{file_name}."
    end
  end

  def data(key)
    if data?(key)
      @data_hash[key]
    else
      puts "WARNING: Couldn't find column #{key} in #{file_name}."
    end
  end

  def data?(key)
    @bulk_names.include?(key)
  end

  def header?(key)
    @header_names.include?(key)
  end

  def data_at_model_number(key, n)
    if data?(key)
      @data_hash[key][index_of_model_number(n)]
    else
      puts "WARNING: Couldn't find column #{key} in #{file_name}."
    end
  end

  def where(*keys)
    keys.each do |key|
      raise "#{key} not a recognized data category." unless data?(key)
    end
    unless block_given?
      raise "Must provide a block for WHERE to test values of provided keys." 
    end
    selected_indices = Array.new
    data(keys[0]).each_index do |i|
      params = keys.map { |key| data(key)[i] }
      selected_indices << i if yield(*params)
    end
    puts "WARNING: No model numbers/grid points met the selection critera " + 
      "given. Returning and empty array." if selected_indices.empty?
    return selected_indices    
  end

  private
  def read_one_line(file_name, line_number)
    File.open(file_name) do |file|
      current_line = 1
      file.each_line do |line|
        return line if line_number == current_line
        current_line += 1
      end
    end
  end
  def remove_backups(dbg)
    # make a list of the ones to be removed
    lst = []
    n = data('model_number').length
    (n-1).times do |k|
      lst << k if data('model_number')[k] >= data('model_number')[k+1..-1].min
    end
    return if lst.length == 0
    puts "remove #{lst.length} models because of backups" if dbg
    lst = lst.sort
    @bulk_data.each { |vec| vec.prune!(lst) }
    nil
  end
  def index_of_model_number(n)
    raise "No 'model_number' data heading found in #{file_name}.
       Cannot match to model number #{n}." unless data?('model_number')
    raise "No such model number: #{n.to_f} in column 'model_number' of file
      #{file_name}." unless data('model_number').include?(n.to_f)
    data('model_number').index(n.to_f)
  end
end


# MESAProfileIndex class provides easy access to the data in a mesa profile
# index file.  It is meant primarily as a helper class to the MESALogDir class
# but can stand on its own.
#
# EXAMPLES:
#
# intialization:
# index = MESAProfileIndex.new('~/mesa/star/work/LOGS/profiles.index')
# index.model_numbers # => Sorted Dvector of model numbers that have available
#   profiles
#
# index.profile_numbers # => Dvector of profile numbers ordered by model number
# index.have_profile_with_model_number?(num) # =>  true if there is a profile
#   corresponding to model number number. false otherwise
#
# index.have_profile_with_profile_number?(num) # =>  true if there is a profile
#    with profile number num
#
# index.profile_with_model_number(num) # => profile number (integer) that
#   corresponds to model number num. If there is none, returns nil
#

class MESAProfileIndex
  attr_reader :model_numbers, :profile_numbers
  def initialize(filename)
    @model_numbers = Dobjects::Dvector.new
    @priorities = Dobjects::Dvector.new
    @profile_numbers = Dobjects::Dvector.new
    @data_array = [@model_numbers, @priorities, @profile_numbers]
    Dobjects::Dvector.read(filename, @data_array, 2)
    @model_number_hash = {}
    @model_numbers.each_with_index do |num, i|
      @model_number_hash[num.to_i] = @profile_numbers[i].to_i
    end
    @profile_number_hash = @model_number_hash.invert
    @profile_numbers.sort! do |num1, num2|
      @profile_number_hash[num1.to_i] <=> @profile_number_hash[num2.to_i]
    end
    @model_numbers.sort!
    return nil
  end
  def have_profile_with_model_number?(model_number)
    @model_numbers.include?(model_number)
  end
  def have_profile_with_profile_number?(profile_number)
    @profile_numbers.include?(profile_number)
  end
  def profile_with_model_number(model_number)
    @model_number_hash[model_number]
  end
end

# The MESALogDir class is meant to be an all-encompassing class that deals with
# history and profile files through one interface. If this file is located in
# your work directory, many defaults are set already to make things easier.
#
# Examples:
#
# l = MESALogDir.new(:log_path       => '~/mesa/star/work/LOGS',
#                    :profile_prefix => 'profile',
#                    :profile_suffix => 'data',
#                    :history_file   => 'history.data',
#                    :index_file     => 'profiles.index')
# NOTE: All values of the intitialization hash have default values as shown
#       in the next five accessor methods. You should only have to set the
#       last four values if you have made specific changes, are reading data
#       from an old (or new, I suppose) version of MESA that has different
#       default file names.
#
# l.log_path       # returns the path string; what you used to initialize
# l.profile_prefix # prefix for profile files (default is 'profile')
# l.profile_suffix # suffix for profile files (default is 'data')
# l.history_file   # name of history file (default is 'history.data')
# l.index_file     # name of profile index file (default is 'profiles.index')
#
# l.contents        # returns array of strings containing names of all files in
#                     log_path
# l.profiles        # returns a MESAProfileIndex object built from index_file
#
# NOTE: ALL MESAProfileIndex METHODS ARE AVAILABLE TO MESALogDir OBJECTS AS WELL
#
# l.history_data    # returns MESAData instance from history_file
#                   # same as doing MESAData.new(log_path + '/' + history_file)
# l.history         # alias of l.history_data
#
#   l.select_models(keys) { |val1, val2, ...| test(val1, val2, ...)} # =>
#     Dvector of model numbers whose history values of the given key categories
#     pass the test in the block. For example,
#
#   late_time_model_nums = l.select_models('star_age', 'log_L') do |age, l|
#     age > 1e5 and l > 2
#   end
#
#   should return a Dvector of all model numbers where the age is greater than
#   1e5 AND log_L > 2 AND there is an available profile in log_path
#
# l.profile_data(params) # =>  MESAData instance for profile specified in params
#   params = {:profile_number => num1, :model_number => num2}
#     If no parameters are given, it defaults to the profile with the largest
#     model number (i.e. the latest profile saved). If a model number is given,
#     the profile that corresponds to that profile number is used, unless there
#     is no such profile, in which case it will default to the last one saved.
#     If an explicit profile number is given, it is used, even if a model
#     number is given. An explicit profile number must be correct or else it
#     will fail (no falling back to the default).

class MESALogDir
  attr_reader :contents, :history_file, :profiles, :profile_prefix, :log_path,
    :index_file, :profile_suffix
  def initialize(params = {})
    params = {'log_path' => 'LOGS', 'profile_prefix' => 'profile',
      'profile_suffix' => 'data', 'history_file' => 'history.data',
      'index_file' => 'profiles.index'}.merge(params)
    @log_path = params['log_path']
    @profile_prefix = params['profile_prefix']
    @profile_suffix = params['profile_suffix']
    @history_file = params['history_file']
    @index_file = params['index_file']
    # raise "Invalid log directory: #{log_path}." unless Dir.exist?(log_path)
    @contents = Dir.entries(@log_path)
    raise "No profile index file, #{@index_file}, in #{@log_path}." unless
      @contents.include?(@index_file)
    raise "No history file, #{@history_file}, in #{@log_path}." unless
      @contents.include?(@history_file)
    @profiles = MESAProfileIndex.new("#{@log_path}/#{@index_file}")
    @h = MESAData.new("#{log_path}/#{history_file}")
  end

  def profile_numbers
    profiles.profile_numbers
  end

  def model_numbers
    profiles.model_numbers
  end

  def have_profile_with_model_number?(model_number)
    model_numbers.include?(model_number)
  end

  def have_profile_with_profile_number?(profile_number)
    profile_numbers.include?(profile_number)
  end

  def profile_with_model_number(model_number)
    profiles.profile_with_model_number(model_number.to_i)
  end

  def history_data
    @h
  end

  alias_method :history, :history_data

  # def select_models(key)
  #   model_numbers.select { |num| yield(@h.data_at_model_number(key, num)) }
  # end
  
  def select_models(*keys)
    keys.each do |key|
      raise "#{key} not a recognized data category." unless @h.data?(key)
    end
    unless block_given?
      raise "Must provide a block for SELECT_MODELS to test values of" + 
      " provided keys."
    end
    
    model_numbers.select do |num|
      params = keys.map { |key| @h.data_at_model_number(key, num) }
      yield(*params)
    end
  end

  def profile_data(params = {})
    # default behavior is to load profile of last model available, next
    # preferred number is a specified profile number, and final preference is
    # the profile that corresponds with the given model number, if there is one.
    params = {'model_number' => model_numbers.max,
         'profile_number' => nil}.merge(params)
    model_number = params['model_number'].to_i
    profile_number = params['profile_number'].to_i if params['profile_number']
    unless (profile_number or not(model_numbers.include?(model_number)))
      profile_number = @profiles.profile_with_model_number(model_number)
    end
    if profile_number
      profile_file_name ="#{@profile_prefix}#{profile_number}.#{profile_suffix}"
      unless @contents.include?(profile_file_name)
        raise "No profile file, #{profile_file_name}, in #{@log_path}."
      end
      MESAData.new("#{@log_path}/#{profile_file_name}")
    else
      unless @profiles.have_profile_with_model_number?(model_number)
        raise "No profile corresponding to model number #{model_number} in
          #{@index_file}."
      end
      MESAData.new("#{@log_path}/#{@profile_prefix}
        #{@profiles.profile_with_model_number(model_number)}.#{@profile_suffix}"
        )
    end
  end
end
