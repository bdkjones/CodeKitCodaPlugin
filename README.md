CodeKit Coda 2 Plugin
==============================

This repo contains the source code for the CodeKit Coda 2 Plugin. 



### The Problem This Solves

You open a website in Coda to edit it, but forget to launch CodeKit and add the project to the app so that your changes are compiled. This plugin does that automatically.




----------------------------------

### How The Plugin Works

Anytime you open a Coda Site, this plugin looks for a `config.codekit` file in the Site's local folder. If one is found, the plugin launches CodeKit 2 (if it's not running) and makes sure that folder is in CodeKit as a project. 

If no `config.codekit` file is found in the Site folder, or if you open a file in Coda that is not part of a Site, the plugin starts at the folder containing the file you opened and walks back through every parent folder until it finds one that contains a 'config.codekit' file. When it does, it makes sure that folder is in CodeKit.

Note: if no `config.codekit` file is found in any parent folder, the plugin does nothing. This means that when you start a new project, you must manually add its folder to CodeKit the first time. 

Warning: you should avoid putting `config.codekit` files in random directories such as "/Users/[your user name]", or this plugin will add that whole folder to CodeKit. 




----------------------------------

### Requirements

1) Coda 2.0.1+
2) CodeKit 2.1.8+
3) Xcode 6+ on OS 10.9.5+ to build the source.

To build, clone the repo, open it in Xcode and click the "build and run" button. This generates a bundle which you'll find under the "products" folder in the Xcode sidebar. Drag that bundle onto Coda's Dock icon to install the plugin. 






----------------------------------

### License

The plugin and this source code are released under the MIT License.


