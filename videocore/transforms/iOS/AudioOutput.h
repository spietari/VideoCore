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

#ifndef __videocore__AudioOutput__
#define __videocore__AudioOutput__

#include <iostream>
#include <videocore/transforms/ITransform.hpp>

#import <CoreAudio/CoreAudioTypes.h>
#import <AudioToolbox/AudioToolbox.h>

@class AudioOutputInterruptionHandler;

namespace videocore { namespace iOS {
    
    class AudioOutput : public ITransform
    {
    public:
        AudioOutput(double sampleRate = 44100., int channelCount = 2);
        ~AudioOutput();
        
        void setOutput(std::shared_ptr<IOutput> output) { m_output = output; };
        void pushBuffer(const uint8_t* const data, size_t size, IMetadata& metadata);
        
        /*! Used by the Audio Unit as a callback method */
        void inputCallback(uint8_t* data, size_t data_size, int inNumberFrames);
        
        void interruptionBegan();
        void interruptionEnded();
        
        AudioBuffer            m_AudioBuffer;
        
    private:
        std::weak_ptr<IOutput> m_output;
        
        AudioOutputInterruptionHandler*   m_interruptionHandler;
        
        AudioComponentInstance m_audioUnit;
        AudioComponent         m_component;
        
        double m_sampleRate;
        int m_channelCount;
    };
}
}
@interface AudioOutputInterruptionHandler : NSObject
{
@public
    videocore::iOS::AudioOutput* _source;
}
- (void) handleInterruption: (NSNotification*) notification;
@end
#endif /* defined(__videocore__AudioOutput__) */
