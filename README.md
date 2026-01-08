# Godot SafeLoad
**This is a work in progress. Use at your own risk!**

SafeLoad is an addon for Godot 4.5 which has for goal to make loading resources safer.

I created this addon because I wanted to let players create levels for my game and allow them to use the 
Godot editor to do so. But I realized that malicious users could hide dangerous code in resources, scenes and 
simply in custom scripts. I did not find another addon that suited my needs, so I decided to make my own!

## SafeLoadConfig
SafeLoadConfig is a resource used to store the parameters for the SafeLoad.

When double clicking on the config ".tres" file, it will open an editor on the left:
![SafeLoadConfig editor](readme_attachments/safeload_config_editor.png)

Clicking on a class will move it from allowed to disallowed, same for the opposite.

Don't forget to press the save button.

## SafeLoad
To use SafeLoad to load a file, you can simply do:
```gdscript
SafeLoad.safe_load(path_to_your_file, safeload_config)
```
It is optional to give SafeLoad a config, but it is highly recommended as it allows you to whitelist a 
small number of classes while the rest is blocked.

If the file is not safe, SafeLoad will push_error and return null, otherwise it simply load the resource.

## How does it work?
SafeLoad reads the content of the file before loading it. It looks for "markers", for example:
- [gd_scene load_steps=2 format=3]
- [ext_resource type="Script" path="res://addons/safeload/SafeLoadConfigCreator.gd" id="1_oh3wd"]

It verifies that all resources, nodes and scripts are in the allowed classes.

If it finds built-in script in a scene, it will not be considered safe.

All external resources are verified with SafeLoad.safe_load().

In ".gd" files, it looks for a line starting with class_name, then the first word after it for the name 
of the class.

## Want to help?
I am open to any suggestions.

Also, I would be happy if you tried to break SafeLoad and told me what passed through, your findings could 
help improve the safety of SafeLoad!

You can DM me on Reddit at u/Gyrcas if you have suggestions or found a way to break SafeLoad.