# ALSound
Copyright (C) 2013-2018 Manuel Sainz de Baranda y Goñi.
Released under the terms of the [MIT License](LICENSE).

A better alternative to [NSSound](http://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSSound_Class) without its main problem: The lag that sometimes occurs when playing the sound for the first time. This makes ALSound more suitable for being used in little videogames.

No instructions needed, just copy _"ALSound.m"_ and _"ALSound.h"_ to your project, then add _"OpenAL.framework"_ and _"AudioToolbox.framework"_ to the _"Link Binary With Libraries"_ build phase in your project settings, and then use this class like NSSound. That's all.

If you find any bug, please, tell me.
