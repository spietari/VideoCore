/*
 
 Video Core
 Copyright (c) 2014 James G. Hurley
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */

//#include <dlfcn.h>
#include <videocore/transforms/iOS/AudioOutput.h>
#include <videocore/mixers/iAudioMixer.hpp>

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#define kOutputBus 0
#define kInputBus 1

@implementation AudioOutputInterruptionHandler

- (void) handleInterruption:(NSNotification*)notification
{
    NSDictionary* userInfo = notification.userInfo;
    
    if([userInfo[AVAudioSessionInterruptionTypeKey] intValue] == AVAudioSessionInterruptionTypeBegan) {
        _source->interruptionBegan();
    } else {
        _source->interruptionEnded();
    }
}

@end

static OSStatus playbackCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData)
{
    videocore::iOS::AudioOutput* audioOutput = static_cast<videocore::iOS::AudioOutput*>(inRefCon);
    AudioBuffer buffer = ioData->mBuffers[0];
    UInt32 size = buffer.mDataByteSize < audioOutput->m_AudioBuffer.mDataByteSize ? buffer.mDataByteSize : audioOutput->m_AudioBuffer.mDataByteSize;
    memcpy(buffer.mData, audioOutput->m_AudioBuffer.mData, size);
    buffer.mDataByteSize = size;
    return noErr;
}

namespace videocore { namespace iOS {
    
    AudioOutput::AudioOutput(double sampleRate, int channelCount)
    : m_sampleRate(sampleRate), m_channelCount(channelCount)
    {
        AudioComponentDescription acd;
        acd.componentType = kAudioUnitType_Output;
        acd.componentSubType = kAudioUnitSubType_RemoteIO;
        acd.componentManufacturer = kAudioUnitManufacturer_Apple;
        acd.componentFlags = 0;
        acd.componentFlagsMask = 0;
        
        m_component = AudioComponentFindNext(NULL, &acd);
        
        AudioComponentInstanceNew(m_component, &m_audioUnit);
        if(!m_audioUnit) {
            DLog("AudioComponentInstanceNew failed");
            return ;
        }
        
        UInt32 flagOne = 1;
        
        OSStatus status;
        
        status = AudioUnitSetProperty(m_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &flagOne, sizeof(flagOne));
        
        AudioStreamBasicDescription desc = {0};
        desc.mSampleRate = m_sampleRate;
        desc.mFormatID = kAudioFormatLinearPCM;
        desc.mFormatFlags = (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked);
        desc.mChannelsPerFrame = m_channelCount;
        desc.mFramesPerPacket = 1;
        desc.mBitsPerChannel = 16;
        desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;
        desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;
        
        status = AudioUnitSetProperty(m_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &desc, sizeof(desc));
        
        AURenderCallbackStruct cb;
        cb.inputProcRefCon = this;
        cb.inputProc = playbackCallback;
        AudioUnitSetProperty(m_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, kOutputBus, &cb, sizeof(cb));
        
        UInt32 flag = 0;
        status = AudioUnitSetProperty(m_audioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, kOutputBus, &flag,sizeof(flag));
        
        m_AudioBuffer.mNumberChannels = m_channelCount;
        m_AudioBuffer.mDataByteSize = 4096;
        m_AudioBuffer.mData = malloc( 4096 );
        memset(m_AudioBuffer.mData, 0, 4096);
        
        m_interruptionHandler = [[AudioOutputInterruptionHandler alloc] init];
        m_interruptionHandler->_source = this;
        
        [[NSNotificationCenter defaultCenter] addObserver:m_interruptionHandler selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
        
        AudioUnitInitialize(m_audioUnit);
        status = AudioOutputUnitStart(m_audioUnit);
        if(status != noErr) {
            DLog("Failed to start audio output!");
        }

    }
    
    AudioOutput::~AudioOutput()
    {
        if(m_audioUnit) {
            [[NSNotificationCenter defaultCenter] removeObserver:m_interruptionHandler];
            [m_interruptionHandler release];
            
            AudioOutputUnitStop(m_audioUnit);
            AudioComponentInstanceDispose(m_audioUnit);
            
            free(m_AudioBuffer.mData);
        }
    }
    
    void
    AudioOutput::interruptionBegan() {
        DLog("interruptionBegan");
        AudioOutputUnitStop(m_audioUnit);
    }
    void
    AudioOutput::interruptionEnded() {
        DLog("interruptionEnded");
        AudioOutputUnitStart(m_audioUnit);
    }
    
    void
    AudioOutput::pushBuffer(const uint8_t *const data,
                                  size_t size,
                                  videocore::IMetadata &metadata)
    {
        auto output = m_output.lock();
        if(output) {
            output->pushBuffer(data, size, metadata);
        }
        
        AudioBufferMetadata& md = dynamic_cast<AudioBufferMetadata&>(metadata);
        
        memcpy(m_AudioBuffer.mData, data, size);
    }
    
}
}