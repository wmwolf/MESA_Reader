# NAME: MESA_Reader
# AUTHOR: William Wolf
# LAST UPDATED: April 30, 2012
# PURPOSE: Provides access to the MESAData class, which, through the methods header
#          and data, can return a value (header) or DVector (data) the corresponds
#          to the key provided to it. New in this version: access to MESAProfileIndex
#          and MESALogDir classes, described where they appear.
#
# EXAMPLES: 
#    s = MESA_Data.new(filename)  #reads in data from filename (either history or profile)
#    s.header('version_number')   #returns the version number of the profile or model    
#    s.data('log_Teff')           #returns DVector containing log_Teff values from file
#    s.data_at_model_number('log_Teff', 30) # return the value of s.data('log_Teff') from the index i where 
                                            # s.data('model_number')[i] = 30
#    s.header('version_number')   #returns true if 'version_number' is a header category, otherwise false
#    s.data?('log_Teff')          #returns true if 'log_Teff' is a data category in file, otherwise false
#    s.where('log_Teff') {test}   #returns an array of indices for values of s.data('log_Teff') for which 
#                                 #  test is true. Useful for selecting sub-vectors persuant to a test on
#                                 #  another vector, like all luminosities past a certain age.

require 'Tioga/FigureMaker' #gives access to DVectors

class MESAData
  include Tioga
  attr_reader :file_name, :header_names, :header_data, :bulk_names, :bulk_data
  def initialize(file_name, scrub = true)
    # In this context, rows start at 1, not 0. These can and should be changed if MESA conventions change.
    
    header_names_row = 2
    header_data_row = header_names_row + 1
    bulk_names_row = 6
    bulk_data_start_row = bulk_names_row + 1
    
    @file_name = file_name
    @header_names = read_one_line(@file_name, header_names_row).chomp.split
    @header_data = read_one_line(@file_name, header_data_row).chomp.split
    @header_hash = {}
    for i in 0...@header_names.size
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
      @bulk_data[i] = Dvector.new
    end
    Dvector.read(file_name,@bulk_data,bulk_data_start_row)
    @data_hash = {}
    @bulk_names.each do |name|
      @data_hash[name] = @bulk_data[@bulk_names.index(name)]
    end
    # puts data('model_number')
    remove_backups(scrub) if data?('model_number')
    return nil
  end
  
  def header(key)
    @header_hash[key]
  end
  
  def data(key)
    @data_hash[key]
  end
  
  def data?(key)
    @bulk_names.include?(key)
  end
  
  def header?(key)
    @header_names.include?(key)
  end
  
  def data_at_model_number(key, n)
    @data_hash[key][index_of_model_number(n)]
  end
  
  def where(key)
    raise "#{key} not a recognized data category." unless data?(key)
    raise "Must provide a block for WHERE to test #{key}." unless block_given?
    selected_indices = Array.new
    for i in 0...data(key).length
      selected_indices << i if yield(data(key)[i])
    end
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
     raise "No 'model_number' data heading found in #{file_name}. Cannot match to model number #{n}." unless data?('model_number')
     data('model_number').index(n.to_f)
   end
end 


# MESAProfileIndex class provides easy access to the data in a mesa profile index file.
# It is meant primarily as a helper class to the MESALogDir class but can stand on its own.
# 
# Examples:
#
# index = MESAProfileIndex.new('~/mesa/star/work/LOGS/profiles.index') # initialization
# index.model_numbers   # Gives list of model numbers that have available profiles
# index.profile_numbers # Gives sorted list of profile numbers ordered by model number
# index.have_profile_with_model_number?(num)   # Returns true if there is a profile 
#                                                corresponding to model number num
# index.have_profile_with_profile_number?(num) # Returns true if there is a profile
#                                                with profile number num
# index.profile_with_model_number(num)         # Returns the profile number that 
#                                                corresponds to model number num. If 
#                                                there is none, returns nil
#



class MESAProfileIndex
  include Tioga
  attr_reader :model_numbers, :profile_numbers
  def initialize(filename)
    @model_numbers = Dvector.new
    @priorities = Dvector.new
    @profile_numbers = Dvector.new
    @data_array = [@model_numbers, @priorities, @profile_numbers]
    Dvector.read(filename, @data_array, 2)
    @model_number_hash = {}
    @model_numbers.each_with_index { |num, i| @model_number_hash[num.to_i] = @profile_numbers[i].to_i }
    @profile_number_hash = @model_number_hash.invert
    @profile_numbers.sort! { |num1, num2| @profile_number_hash[num1.to_i] <=> @profile_number_hash[num2.to_i] }
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

# The MESALogDir class is meant to be an all-encompassing class that deals with history
# and profile files through one interface. If this file is located in your work directory,
# many defaults are set already to make things easier.
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
# l.contents        # returns array of strings containing names of all files in log_path
# l.profiles        # returns a MESAProfileIndex object built from index_file
# l.profile_numbers # same as l.profiles.profile_numbers
# l.model_numbers   # same as l.profiles.model_numbers
# l.history_data    # returns MESAData instance from history_file
#                   # same as doing MESAData.new(log_path + '/' + history_file)
# l.select_models(key)   # Accepts a history file key (like log_L or model_number)
#                        # and a block involving that key and tests the block on each
#                        # available profile's model number. Then returns the list
#                        # of model_numbers that pass the test. For example
#
#   late_time_model_nums = l.select_models('star_age') { |age| age > 1e5 }
#
#                        # should return a Dvector of all model numbers where the 
#                        # age is greater than 1e5 AND there is an available profile
#                        # in log_path
# l.profile_data(params) # returns a MESAData object for the profile specified in params
#                        # params = {:profile_number => num1, :model_number => num2}
#                        # If no parameters are given, it defaults to the profile with 
#                        # the largest model number (i.e. the latest profile saved).
#                        # If a model number is given, the profile that corresponds to
#                        # that profile number is used, unless there is no such profile,
#                        # in which case it will default to the last one saved. If an 
#                        # explicit profile number is given, it is used, even if a model
#                        # number is given. An explicit profile number must be correct
#                        # or else it will fail (no falling back to the default).

class MESALogDir
  include Tioga
  attr_accessor :log_path, :profile_prefix, :profile_suffix, :history_file, :index_file
  attr_reader :contents, :profiles
  def initialize(params = {})
    params = {'log_path' => 'LOGS', 'profile_prefix' => 'profile', 'profile_suffix' => 'data', 'history_file' => 'history.data', 'index_file' => 'profiles.index'}.merge(params)
    @log_path = params['log_path']
    @profile_prefix = params['profile_prefix']
    @profile_suffix = params['profile_suffix']
    @history_file = params['history_file']
    @index_file = params['index_file']
    # raise "Invalid log directory: #{log_path}." unless Dir.directory?(log_path)
    @contents = Dir.entries(@log_path)
    raise "No profile index file, #{@index_file}, in #{@log_path}." unless @contents.include?(@index_file)
    raise "No history file, #{@history_file}, in #{@log_path}." unless @contents.include?(@history_file)
    @profiles = MESAProfileIndex.new("#{@log_path}/#{@index_file}")
    @h = MESAData.new("#{log_path}/#{history_file}")
  end
  
  def profile_numbers
    @profiles.profile_numbers
  end
  
  def model_numbers
    @profiles.model_numbers
  end
  
  def history_data
    @h
  end
  
  def select_models(key)
    model_numbers.select { |num| yield(@h.data_at_model_number(key, num)) }
  end
  
  def profile_data(params = {})
    # default behavior is to load profile of last model available, next preferred number
    # is a specified profile number, and final preference is the profile that corresponds
    # with the given model number, if there is one.
    params = {'model_number' => model_numbers.max, 'profile_number' => nil}.merge(params) 
    model_number = params['model_number'].to_i
    profile_number = params['profile_number'].to_i if params['profile_number']
    profile_number = @profiles.profile_with_model_number(model_number) unless (profile_number or not(model_numbers.include?(model_number)))
    if profile_number
      profile_file_name = "#{@profile_prefix}#{profile_number}.#{profile_suffix}"
      raise "No profile file, #{profile_file_name}, in #{@log_path}." unless @contents.include?(profile_file_name)
      MESAData.new("#{@log_path}/#{profile_file_name}")
    else
      raise "No profile corresponding to model number #{model_number} in #{@index_file}." unless @profiles.have_profile_with_model_number?(model_number)
      MESAData.new("#{@log_path}/#{@profile_prefix}#{@profiles.profile_with_model_number(model_number)}.#{@profile_suffix}")
    end
  end
end
