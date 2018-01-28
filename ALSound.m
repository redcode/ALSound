// ALSound
// Copyright (C) 2013-2018 Manuel Sainz de Baranda y Goñi.

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included
// UNALTERED in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.


#import "ALSound.h"
#import <AudioToolbox/AudioToolbox.h>

#define AUDIO_FORMAT_FLAGS (kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsSignedInteger)

static NSMutableDictionary* sounds_  = nil;
static ALCcontext*	    context_ = NULL;


@implementation ALSound


	+ (ALSound *) soundNamed: (NSString *) fileName
		{
		ALSound *sound;

		//-----------------------------------------------------------------------.
		// If the sound is cached it's not necessary to create another instance. |
		//-----------------------------------------------------------------------'
		if (sounds_ && (sound = [sounds_ objectForKey: fileName])) return sound;

		ExtAudioFileRef		    file;
		SInt64			    frameCount;
		UInt32			    size = sizeof(UInt64);
		UInt32			    descriptionSize = sizeof(AudioStreamBasicDescription);
		AudioStreamBasicDescription description;
		uint16_t*		    buffer;

		//----------------------.
		// Open the sound file. |
		//----------------------'
		if (	noErr != ExtAudioFileOpenURL
				((CFURLRef)[[[NSURL alloc] initFileURLWithPath: [[NSBundle mainBundle]
					pathForResource: [fileName stringByDeletingPathExtension]
					ofType:		 [fileName pathExtension]]]
				 autorelease],
				 &file)
		)
			return nil;

		//-----------------------------------------------------------.
		// Obtain the number of samples and the format's properties. |
		//-----------------------------------------------------------'
		if (	noErr != ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &size,		 &frameCount) ||
			noErr != ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat,   &descriptionSize, &description)
		)
			goto close_file_and_return_nil;

		//---------------------------------------------------------------------------------------.
		// If the format is not PCM, adjust properties to convert the samples to PCM at reading. |
		//---------------------------------------------------------------------------------------'
		if (description.mFormatID != kAudioFormatLinearPCM || description.mFormatFlags != AUDIO_FORMAT_FLAGS)
			{
			description.mFormatID	 = kAudioFormatLinearPCM;
			description.mFormatFlags = AUDIO_FORMAT_FLAGS;

			ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, descriptionSize, &description);
			}

		//----------------------------------------------.
		// Create the buffer where to read the samples. |
		//----------------------------------------------'
		if ((buffer = malloc((size_t)(frameCount * description.mBytesPerFrame))) == NULL)
			goto close_file_and_return_nil;

		AudioBufferList bufferList;
		bufferList.mNumberBuffers	       = 1;
		bufferList.mBuffers[0].mNumberChannels = description.mChannelsPerFrame;
		bufferList.mBuffers[0].mDataByteSize   = description.mBytesPerFrame * (UInt32)frameCount;
		bufferList.mBuffers[0].mData	       = buffer;

		//---------------------------------------------------------.
		// Seek to the beginning of file and read all the samples. |
		//---------------------------------------------------------'
		size = (UInt32)frameCount;

		if (	noErr != ExtAudioFileSeek(file, 0) ||
			noErr != ExtAudioFileRead(file, &size, &bufferList)
		)
			goto free_buffer_close_file_and_return_nil;

		//-----------------------.
		// Close the sound file. |
		//-----------------------'
		ExtAudioFileDispose(file);

		//----------------------.
		// Create the instance. |
		//----------------------'
		if ((sound = [[self alloc] init]))
			{
			sound->_buffer = buffer;

			//------------------------------------------.
			// If there was not any instance created... |
			//------------------------------------------'
			if (!sounds_)
				{
				//------------------------------.
				// Create the cache dictionary. |
				//------------------------------'
				CFDictionaryValueCallBacks callbacks = {0, NULL, NULL, CFCopyDescription, CFEqual};

				sounds_ = (id)CFDictionaryCreateMutable
					(NULL, (CFIndex)0, &kCFTypeDictionaryKeyCallBacks, &callbacks);

				//--------------------.
				// Initialize OpenAL. |
				//--------------------'
				const ALCchar *defaultDevice = alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
				ALCdevice *soundDevice = alcOpenDevice(defaultDevice);

				context_ = alcCreateContext(soundDevice, NULL);
				alcMakeContextCurrent(context_);
				alcProcessContext(context_);

				alListener3f(AL_POSITION,    0, 0,  0);
				alListener3f(AL_VELOCITY,    0, 0,  0);
				alListener3f(AL_ORIENTATION, 0, 0, -1);
				}

			//---------------------------------.
			// Create the OpenAL sound source. |
			//---------------------------------'
			alGenSources(1, &sound->_sourceID);
			alSource3f(sound->_sourceID, AL_POSITION, 0, 0, 0);
			alSource3f(sound->_sourceID, AL_VELOCITY, 0, 0, 0);
			alSourcei (sound->_sourceID, AL_LOOPING, AL_FALSE);

			//--------------------------------------------------.
			// Create the buffer for the samples of the source. |
			//--------------------------------------------------'
			alGenBuffers(1, &sound->_bufferID);

			ALenum audioFormat = 0;

			if (description.mChannelsPerFrame == 1)
				{
				if (description.mBitsPerChannel == 8) audioFormat = AL_FORMAT_MONO8;
				else if (description.mBitsPerChannel == 16) audioFormat = AL_FORMAT_MONO16;
				}

			else if (description.mChannelsPerFrame == 2)
				{
				if (description.mBitsPerChannel == 8) audioFormat = AL_FORMAT_STEREO8;
				else if (description.mBitsPerChannel == 16) audioFormat = AL_FORMAT_STEREO16;
				}

			alBufferData
				(sound->_bufferID, audioFormat, buffer,
				 (ALsizei)(frameCount * description.mBytesPerFrame),
				 (ALsizei)description.mSampleRate);

			//---------------------------------------.
			// Add the buffer to the source's queue. |
			//---------------------------------------'
			alSourceQueueBuffers(sound->_sourceID, 1, &sound->_bufferID);

			//---------------------------------.
			// Add this instance to the cache. |
			//---------------------------------'
			[sounds_ setObject: sound forKey: fileName];
			}

		else free(buffer);

		return [sound autorelease];

		free_buffer_close_file_and_return_nil:
		free(buffer);

		close_file_and_return_nil:
		ExtAudioFileDispose(file);
		return nil;
		}


	- (void) dealloc
		{
		[sounds_ removeObjectForKey: [[sounds_ allKeysForObject: self] objectAtIndex: 0]];
		alSourceStop(_sourceID);
		alSourceUnqueueBuffers(_sourceID, 1, &_bufferID);
		alDeleteBuffers(1, &_bufferID);
		alDeleteSources(1, &_sourceID);
		free(_buffer);

		if (![sounds_ count])
			{
			[sounds_ release];
			sounds_ = nil;

			alcSuspendContext(context_);
			alcDestroyContext(context_);
			}

		[super dealloc];
		}


	- (void) play {alSourceStop(_sourceID); alSourcePlay(_sourceID);}
	- (void) stop {alSourceStop(_sourceID);}


@end
