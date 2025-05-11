# ✅ Core Image Filters for Negative Lab Pro Emulation in Noislume

This checklist includes Core Image filters that can help you replicate the image editing features of Negative Lab Pro using `CIRAWFilter` and other native tools.

---

## 🎞️ Essential Filters

### 🔁 Inversion & Masking

* [ ] `CIColorMatrix` – Custom channel inversion and orange mask compensation
* [ ] `CIColorInvert` – Basic inversion (optional, less precise)

### 🎛 Tone & Contrast

* [ ] `CIToneCurve` – Apply S-curves or scanner-style tone mappings
* [ ] `CIColorControls` – Adjust contrast, brightness, saturation
* [ ] `CIHighlightShadowAdjust` – Separate highlight/shadow control
* [ ] `CIGammaAdjust` – Manual gamma tweaks for film response
* [ ] `CIWhitePointAdjust` – Set neutral point for white balance

### 🎨 Color Grading

* [ ] `CIColorCube` / `CIColorCubeWithColorSpace` – Film LUTs or scanner emulation
* [ ] `CIColorPolynomial` – Advanced channel tone remapping
* [ ] `CITemperatureAndTint` – White balance matching by kelvin/tint
* [ ] `CIVibrance` – Boost muted tones without oversaturation

### 🧼 Sharpening & Noise

* [ ] `CINoiseReduction` – Grain smoothing (if desired)
* [ ] `CISharpenLuminance` – Luminance-only sharpening
* [ ] `CIUnsharpMask` – Traditional high-pass-style sharpening

### 📐 Geometry & Framing

* [ ] `CICrop` – Final output dimensions
* [ ] `CIAffineTransform` – Rotate/scale adjustments
* [ ] `CIStraightenFilter` – Align mis-scanned frames

---

## ⚡ Optional Enhancements

* [ ] `CIAreaAverage` – Sample base film color for orange mask
* [ ] `CISepiaTone` – Stylized warm tone for B\&W
* [ ] `CIColorMonochrome` – Grayscale tone mapping
* [ ] `CIVignette` / `CIVignetteEffect` – Add soft film-style corner falloff
* [ ] `CILanczosScaleTransform` – High-quality downscaling when exporting

---

Use this checklist when designing your filter chain or evaluating features for implementation in Noislume. Let me know if you want a JSON, Swift config, or filter graph version of this.
