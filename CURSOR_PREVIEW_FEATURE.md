# Film Base Cursor Preview Feature

## Overview

The Film Base Cursor Preview is a new feature that provides real-time visual feedback when sampling film base colors. It shows a color preview and RGB values that follow the cursor when in film base sampling mode.

## How It Works

1. **Activation**: The cursor preview appears automatically when film base sampling mode is active (`viewModel.isSamplingFilmBase = true`)
2. **Real-time Sampling**: As you move the cursor over the image, the preview samples colors from the film base sampling image (the negative without inversion)
3. **Visual Feedback**: Shows both a color swatch and numeric RGB values (0-255 range)
4. **Smart Positioning**: The preview automatically adjusts its position to stay visible on screen

## Key Features

### Visual Elements
- **Color Swatch**: 40x40 pixel rounded rectangle showing the sampled color
- **RGB Values**: Numeric display of Red, Green, and Blue components (0-255)
- **Modern Design**: Semi-transparent black background with white text and drop shadows
- **Auto-positioning**: Stays offset from cursor and adjusts to avoid screen edges

### Performance Optimizations
- **Throttled Sampling**: 50ms delay between samples to prevent excessive CPU usage
- **Task Cancellation**: Previous sampling tasks are cancelled when cursor moves rapidly
- **Bounds Checking**: Only samples when cursor is within the image frame
- **Automatic Cleanup**: Tasks are cancelled when view disappears

## Technical Implementation

### Key Components

1. **FilmBaseCursorPreview.swift**: The main SwiftUI view component
   - Tracks cursor position using `onContinuousHover`
   - Manages color sampling with throttling
   - Handles positioning and visibility logic

2. **InversionViewModel.sampleColorForPreview()**: Public method for color sampling
   - Uses `.filmBaseSampling` processing mode
   - Returns color tuple with RGBA components
   - Handles error cases gracefully

3. **Integration in CroppingView**: 
   - Tracks cursor position state
   - Overlays the preview during film base sampling

### Code Structure
```swift
// FilmBaseCursorPreview usage in CroppingView
FilmBaseCursorPreview(
    viewModel: viewModel,
    cursorPosition: cursorPosition,
    imageFrame: activeImageFrame
)
```

## Usage Instructions

1. Load a RAW image in Noislume
2. Navigate to the Film Base Neutralization section
3. Click "Sample Film Base Color" button
4. Move cursor over the image to see real-time color preview
5. Click on the desired film base area to set the sample
6. The preview disappears when sampling mode is deactivated

## Benefits

- **Better User Experience**: Visual feedback helps users understand what color will be sampled
- **Accuracy**: Ensures users sample from appropriate film base areas (bright orange/amber regions)
- **Efficiency**: Reduces trial-and-error when finding good film base samples
- **Professional Workflow**: Provides precise RGB feedback for technical users

## Platform Support

- **macOS Only**: Currently implemented for macOS using `onContinuousHover`
- **SwiftUI**: Native SwiftUI implementation with modern design patterns
- **Performance**: Optimized for real-time interaction without impacting image processing

## Future Enhancements

Potential improvements for future versions:
- iOS support using touch gestures
- Customizable preview size and position
- Additional color space representations (HSB, Lab)
- Preview history/comparison features
- Magnification of the sampled area 