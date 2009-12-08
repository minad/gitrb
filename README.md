GitRb - Native ruby interface to git
====================================

GitRb is a native interface to git. It is based on git_store by Matthias Georgi.

### Installation

GitStore can be installed as gem easily:

    $ gem sources -a http://gemcutter.org
    $ sudo gem install gitrb

### Usage Example

    require 'gitrb'

    repo = Gitrb::Repository.new(:path => '/tmp/repository', :create => true)
    repo.transaction do
      repo.root['textfile1'] = Gitrb::Blob.new(:data => 'text')
      repo.root['textfile2'] = Gitrb::Blob.new(:data => 'text')
    end

    puts repo.root['textfile1'].data
    puts repo.root['textfile2'].data

