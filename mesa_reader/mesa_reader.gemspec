Gem::Specification.new do |s|
  s.name = 'mesa_reader'
  s.version = '0.1.0'
  s.authors = ["William Wolf"]
  s.date = %q{2014-12-01}
  s.summary = 'MesaReader - a module containing classes for storing MESA data output.'
  s.description = <<-LONGDESC
    MesaReader is a ruby module that contains three classes, MesaData, MesaProfileIndex,
    and MesaLogDir. These classes are intended to read in three types of files
    or directories, MESA history/profile logs, MESA profile indexes, and entire MESA
    LOGS directories, respectively. The resulting objects can then be maniuplated
    to return useful data in a ruby or tioga script.

    In addition to simple returning of data columns (the primary function of the MesaData
    class), some basic searching features are built-in, allowing you to search for profiles
    that correspond to something in the history, or for parts of history columns that
    depend on other history columns. All returned vectors have many built-in methods since
    they are DVectors from the DObjects module in Tioga, which is a requirement.

    For detailed instructions, see the readme on the github page at 

    https://github.com/wmwolf/MESA_Reader
  LONGDESC
  s.email = 'wmwolf@physics.ucsb.edu'
  s.files = ['README.md', 'lib/mesa_reader.rb']
  s.homepage = 'https://wmwolf.github.io'
  s.has_rdoc = false
  s.licenses = ['MIT']
  s.add_development_dependency 'tioga', '>= 1.14'
end