#MESA\_Reader.rb: The easy way to access your MESA data
___

## What Is MESA\_Reader?
This file gives you access to three classes: MESAData, MESAProfileIndex, and
MESALogDir. The primary use is intended for plotting in
[Tioga](http://www.kitp.ucsb.edu/members/PM/paxton/tioga.html), but as the
tools become more sophisticated, analysis can be done on the fly with irb or
standalone scripts.

## Installation ##

### Prerequisites ###

To install MESA\_Reader, you must already have Tioga installed, since it makes
extensive use of DVectors for bulk data storage and easy access for Tioga
plots. Obivously you need an installation of Ruby. I haven't found any conflicts with Ruby 1.8.7, 1.9.3, or 2.0, and I'm told it now works with 1.8.6. 

### Local Installation ###

Placing the file in your work directory may be sufficient if you just plan to
use this for plotting purposes since it will copy over with the rest of the
directory whenever you make a new work directory.

Another possible installation idea that I've been using is to clone the git
repository somewhere sensible on my machine and then create a pointer file in my
Ruby path (see below). For instance, I have a file in `/usr/lib/ruby/` called 
`MESA_Reader.rb` that has one line:

	require '/Users/wmwolf/Documents/MESA_Reader/MESA_Reader.rb'

That way, the source file is easily accessible in my git repo while also being
readable from Ruby's path. That is, when you tell ruby to require MESA\_Reader,
it will find the file in its path, which will then load the file from your
local repo.

To clone the git repo on  your machine (assuming you
have git installed), `cd` to the directory where you want it installed and clone
it. You'll want to change the path to where you want to install the file, but
the commands are

	cd ~/Documents
	git clone https://github.com/wmwolf/MESA_Reader.git MESA_Reader

which will install the contents of the repo (currently just the MESA\_Reader.rb 
file and this README) into a directory called MESA\_Reader in your Documents
directory. Then any time you want to update to the latest release, you can do

	cd ~/Documents/MESA_Reader
	git pull
	
Or, hopefully, you can make your own additions and push updates for me to add!

### Global Installation ###

For a more permanent solution, put MESA\_Reader.rb in your ruby path. For me
(on a mac), placing it in `/usr/lib/ruby/` did the trick. To see where you
should install the file for global use enter the following line into your
terminal

	ruby -e 'puts $:'
	
This should give you a list of directories that would work for installation. To
update to a newer version of these tools, just move the new file to the same
place.

## Making the Classes Available
In your program (or irb), just start with

	require 'MESA_Reader'
	
If the file is in the same directory as your current working one, it will be
read from there. Otherwise, ruby will search through its available paths for a
file called `MESA_Reader.rb` and load the first one it finds.

## Creating Instances
To create a simple `MESAData` instance, use the class `::initialize` method:

	s = MESAData.new(FILEPATH)
	
where `FILEPATH` is a string that is the path (relative or fully-qualified) to
the file you wish to read in. For instance, if you are in the work directory
and you want to read in the history file, you would use `'LOGS/history.data'`
in place of `FILEPATH`. You can load history or profile files since the basic
`MESAData` object doesn't know the difference (though when loading history
files, it does know to throw out backups, retries, and restarts, ensuring that
the model numbers are monotonically increasing).

To create a `MESAProfileIndex` instance, we'll use that class' `::initialize`
method as well.

	m = MESAProfileIndex.new(FILEPATH)

where now `FILEPATH` is a string containing the path to your profiles index
file, like `'LOGS/profiles.index'`.

Finally, to make a `MESALogDir` instance, we use that class' `::initialize`
method again. Unlike the first two examples, though, this class can take many
more initialization parameters. To use just two of them, here's an example:

	l = MESALogDir.new('log_path' => '~/mesa/star/work/LOGS', 'history_file' => 'history.data')
	
You can also set `'profile_prefix'`, `'profile_suffix'`, and `'index_file'`,
which denote the part of the name of profile before the number, the suffix of a
profile file, and the full name of the index file. The defaults are

	'log_path'       => 'LOGS'
	'profile_prefix' => 'profile'
	'profile_suffix' => 'data'
	'history_file'   => 'history.data'
	'index_file'     => 'profiles.index
	
Normally these shouldn't need to be altered, and so long as you don't have custom-named log directories, `l = MESALogDir.new`, with no options, should suffice.

## MESAData Methods
There are 11 publicly accessible instance methods for `MESAData` objects. Their
usage is detailed below. For convenience, we'll assume that `s` is an instance
of the `MESAData` class. That is, assume we have already done

	s = MESAData.new('LOGS/history.data')

### `#bulk_data`
Returns an array of Dvectors containing the columns from the source file. This
isn't very useful and is really only a diagnostic tool.

### `#bulk_names`
Returns an array of strings that are the names of each of the data columns.
These are the strings at the top of each data column from the source file.
Together with `#bulk_data` forms a hash that is accessed using the `#data`
command to convert data column names into Dvectors.

### `#data(key)`
Accepts a string and returns the corresponding Dvector from `#bulk_data`. This
is the main usage of the class.

	s.data('model_number') => [1.0, 2.0, 3.0, 4.0, ...]
	
Returns `nil` and prints a warning if no such key exists in `s.bulk_names`.

### `#data_at_model_number(key, model_number)`

Accepts a string and a model number (float or integer) and returns the value of
`s.data(key)` at the index corresponding to the given model number. If no such 
data category exists, returns `nil` and prints a warning. An exception will be
thrown if `model_number` is not a data category or if the given model number is
outside the range of `s.data('model_number')`.

### `#data?(key)`
Accepts a string and returns `true` if the entry is found in `s.bulk_names` and
`false` otherwise.

### `#file_name`
Returns a string containing the name of the file that was read into the
instance.

### `#header(key)`
Accepts a string and returns the corresponding value from `#header_data`. The
`key` value must be in `s.header_names` or else it will return `nil` (and a
warning will be printed). Works in much the same way as `#data` but with the
header data rather than the bulk data.

### `#header?(key)`
Accepts a string and returns `true` if the string is in `s.header_names`.

### `#header_data`
Returns an array of all the data in the header row of the source file.

### `#header_names`
Returns an array of strings containing all the names of the header data entries.

### `#where(keys)`
Accepts an arbitrary (at least one) number of strings as arguments, each of
which must be a member of `s.bulk_names`. Then yields each member of
`s.data(key1)`, `s.data(key2)`, etc. into a [required] block and performs a
user-specified test on those data. Returns an array of integers containing the
indices of the set members that passed the test. For example

	s.where('star_age', 'log_L') { |age, lum| age > 1e6 and lum > 2 }
	
returns an array containing the indices , `i` such that 
`s.data('star_age')[i] > 1e6` and `s.data('log_L')[i] > 2`. A common usage
would then be to feed these indices back in to get a subset of an array from
`s.data('star_age')`. For instance, one could get all the values of the
luminosity for times later than a million years via

	s.data('luminosity').values_at(*s.where('star_age) { |age| age > 1e6 })
  
### Magic Methods
Depending on the type of file read in to the object (specifically what ends up
in `s.bulk_names`), you can also access the bulk data through some shorthand
without using the `#data` method. So long as the data name isn't already a 
defined method on the `MESAData` class, you can simply use its name as a method
which just returns `data("#{name}")`. That is, if you load in a history file, 

	s.data('model_number')
  
and

	s.model_number
  
should return the same thing. This is essentially just syntatic sugar, but it
makes for more readable code. The `#data` way of doing things is always invoked
at some point, so it is the "preferred" method of accessing data, but magic
methods should, for nearly all cases, perform just as well unless you have
unfortunately named data categories (starting with numbers, or they are
tragically named the same as an already existing method, like, `nil?`).

If the method name used is not in `s.bulk_names` but is in `s.header_names`,
then it returns the appropriate header data instead. If the name is in both 
the header and data names, the data entry wins (this sometimes happens with 
things like `version_number` and the like). If you use an invalid method (i.e. 
one that is not explicitly defined in the class or its superclass, the basic 
Ruby object `Object`, or a method implicitly defined from the data and header
categories via magic methods) a `NameError` will be thrown, just like it is for
any other case of a bad method call.
 	
## MESAProfileIndex Methods

There are five publicly accessible methods for the `MESAProfileIndex` class,
though likely the only useful methods are `#have_profile_with_model_number?`
and `#profile_with_model_number`, which allow you to obtain a model number from
a model number. In practice, this class isn't very useful on its own, but is
used extensively in the `MESALogDir` class.
	
### `#have_profile_with_model_number?(model_number)`
Accepts an integer, a model number, and returns `true` if there is a profile
available with that model number. Otherwise returns `false`.

### `#have_profile_with_profile_number?(profile_number)`
Accepts an integer, a profile number, and returns `true` if there is a profile
with that profile number. Otherwise returns `false`.

### `#model_numbers`
Returns a Dvector containing all the model numbers that have profiles available.

### `#profile_numbers`
Returns a Dvector containing all the profile numbers available.

### `#profile_with_model_number(model_number)`
Accepts an integer model number and returns the profile number that corresponds
to it. Returns `nil` if there is no such profile.

## `MESALogDir Methods`
We'll suppose we've already made an instance for the purpose of examples via

	l = MESALogDir.new
	
In addition to the methods defined below, all the methods of `MESAProfileIndex` 
are available and are simply called on the internal `MESAProfileIndex` created
within the `MESALogDir` structure.
	
### `#contents`
Returns an array of strings containing names of all the files in the directory
returned by `l.log_path`.

### `#history_data`
Returns a `MESAData` instance made from `l.history_file` in `l.log_path`. This 
object is created at initialization and is thus "free". There's no need to catch
this in a variable to spare the MESAData initialization process each time it is
called.

### `#history` ###
Alias for `history`.

### `#history_file`
Returns the name of the history data file in `l.log_path`.

### `#index_file`
Returns the name of the profile index file in `l.log_path`.

### `#log_path`
Returns a string containing the given path to the logs directory.

### `#profiles`
Returns a `MESAProfileIndex` instance built from `l.index_file`

### `#profile_data(params)`
Accepts two possible integer arguments, `'model_number'` or `'profile_number'`
which specify a profile to be loaded. If neither are given, the profile with
the largest model number (i.e., the last saved profile) is selected. Returns a
`MESAData` object built from this profile. If the model number provided has no
profile (i.e. `l.profiles.profile_with_model_number(params['model_number']) =>
nil`), then the default model number is selected. If a profile number is used,
it will attempt to use it no matter what, triggering an error if the given
profile number is invalid. For example

	p = l.profile_data('model_number' => 300)
	
would set `p` to be a `MESAData` object built from the profile data associated
with model number 300. If no such model number existed, though, it would pull
data from the profile with the largest model number. If we instead used

	p = l.profile_data('model_number' => 300, 'profile_number' => 15)

then `p` would be set to a `MESAData` object with profile number 15. The
`'model_number'` entry is entirely ignored. If there was no profile with
profile number 15, an exception will be raised. Essentially there is never a
time when it is helpful to specify both a model number and a profile number,
and again, if neither are specified, the profile with the largest model number
is used.

Each of these objects are made as this is called. That is, they aren't "sitting
around" like the history MESAData object. As such, these should be captured in
a variable so that they aren't re-constructed each time they are needed.

### `#profile_prefix`
Returns the string containing the profile prefix as defined in the
`MESAProfileIndex` class.

### `#profile_suffix`
Returns the string containing the profile suffix as defined in the
`MESAProfileIndex` class.

### `#select_models(keys)`
Nearly identical to `#where` in the `MESAData` class, but ensures that the
returned model numbers have corresponding profile files. Accepts an arbitrary
number (at least one) of strings that must be in `l.history_data.bulk_names`
and yields successive values of `l.history_data.data(key)` for each key to a
user-specified block that should return a boolean. Only those model numbers
that have available profiles are tested, so the returned Dvector of model
numbers (not indices, like in `#where`) have available profiles *and* pass the
test provided by the user. As an example

	models_to_plot = l.select_models('log_center_T', 'log_center_Rho') { |log_tc, log_rhoc| log_tc > 8 and log_rhoc > 3 }

will return a Dvector of model numbers that have profiles available for reading
in *and* have central temperatures exceeding 1e8 *and* have central densities
exceeding 1e3.

## Some Additional Thoughts
The uses for these classes are pretty generic. As stated earlier, they were
developed primarily to ease plotting MESA data in Tioga, but they are also
quite useful for manipulating the data in their own rite for numerical
purposes. The only reason you might not want to do that is that Ruby isn't the
fastest language available, but then again, if you are dealing with such large
MESA data sets that the computational timescales are getting too long for your
comfort, you are in a pretty remarkable situation. As a practical note, if you
use this in irb and you make an instance of `MESAData`, I'd recommend
folllowing that up with a semi-colon and `nil` unless you want to see a ton of
numbers fly up your screen. For instance, do this

	l = MESALogDir.new; nil
	
The `nil` keeps irb from outputting all the data held in `l`. Or consider using
the wonderful irb replacement [Pry](http://pryrepl.org) which can make
exploring your data outside of plots a much more pleasant experience (for
instance a simple semi-colon will suppress outputting the return value). If you
have any problems with or suggestions for further development of these classes,
please contact me or better yet, make some commits and push the changes for
deployment!
