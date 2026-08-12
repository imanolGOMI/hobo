# Hobo in Two Minutes

## Prerequisites

Before installing Hobo, you must have
[Ruby](http://www.ruby-lang.org/en/) and
[RubyGems](http://docs.rubygems.org/). You will also need the "git" command.

Installing Hobo 2.2 will cause Rails 4 to be installed when the Hobo application generator first runs 'bundle install'.

For example, these are the steps you would need in Ubuntu 12.04:

        sudo apt-get update
        sudo apt-get install -y ruby1.9.3 rubygems nodejs libsqlite3-dev git
        export GEM_HOME=$HOME/.gem
        echo "export GEM_HOME=$HOME/.gem" >> .bashrc
        PATH="$HOME/.gem/bin:$PATH"
        echo 'PATH="$HOME/.gem/bin:$PATH"' >> .bashrc


Note: Hobo 2.2 is currently tested against Rails 4.2.7.1 and Ruby 2.4.3.

## Install Hobo

	gem install hobo

## Create a new Hobo application

NOTE: Before creating a new Hobo application, check if you have the HOBODEV environment variable defined:

	$ echo $HOBODEV
	
If it is defined and points to a local copy of Hobo source, you should temporarily undefine it, otherwise
the generated Gemfile in your new Hobo application will reference the HOBODEV source code instead of the Hobo gem. 
This will likley cause unresolved dependencies when the Hobo application generator runs 'bundle install'. 
You can unset the HOBODEV variable by typing
	
	$ unset HOBODEV

Now, create your new Hobo application:

	hobo new thingybob --setup


(The `--setup` option tells hobo to use the defaults rather than
asking questions about your application.   After you play with
Hobo a bit so that you understand the questions, you will probably
want to omit the `--setup`)


## Add a resource and start the app

There will be lots of output produced as Hobo runs the rails command
and runs the setup generator. This process may take a while, depending
on your internet connection and computer speed.

	cd thingybob
	hobo g resource thing name:string body:text
	hobo g migration

	...Respond to the prompt with 'm'
	...then press enter to chose the default filename

	rails s

And browse to

	http://localhost:3000

And there is your app! You should be able to

* Sign up
* Create and edit Things
* Search for things

That's it. Why not try another of the tutorials on your left?

Note: If you wish to download the gems directly, you can get them from
[RubyGems.org](http://rubygems.org).

The source code for Hobo is available at [github:Hobo/hobo](http://github.com/Hobo/hobo) and additional sources are available in the [github Hobo organization](https://github.com/Hobo)


