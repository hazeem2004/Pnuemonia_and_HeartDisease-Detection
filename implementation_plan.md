# 🫀 Implementation Plan: ECG Heart Disease Detection (WSO-LDA + MOSHO-HANN)

This implementation plan details the strategy, architectural enhancements, and code integrations to introduce a **Heart Disease Detection System** using ECG images in the `ecg_data` folder. The system uses the identical deep learning + WSO-LDA feature selection + MOSHO-HANN optimization strategy.

---

## 🎯 Goal Description

The objective is to expand the existing single-disease application into a **Multi-Diagnostic Clinical Hub** by adding an ECG analysis pipeline:
1. **Model Training Notebook**: Build a fully documented Jupyter Notebook (`train_ecg.ipynb`) in your workspace that processes the `ecg_data` dataset (4 classes: Normal, Abnormal, Myocardial Infarction, Post-MI History), extracts deep features, applies Binary White Shark Optimization (WSO-LDA), runs Multi-Objective Spotted Hyena Optimization (MOSHO) to train HANN, and exports to `ecg_model.onnx`.
2. **FastAPI Backend Integration**: Update `backend/main.py` to host both models (`xray_model.onnx` and `ecg_model.onnx`) and expose a new `POST /predict_ecg` endpoint.
3. **Flutter App Upgrade**: 
   - Transform `home_screen.dart` into a premium **Dashboard/Clinical Hub** with greeting headers, health quick-stats, and modern diagnostic portal cards (X-ray, ECG, Map).
   - Add a premium **ECG Diagnostic Portal Screen** (`ecg_screen.dart`) that mirrors the web/mobile cross-platform architecture we implemented.
   - Refactor `results_screen.dart` to support multi-class outputs with specialized medical guidelines and color palettes tailored to cardiac health.

---

## 🔍 Proposed Changes

```
                         [PneumoAI Web/Mobile App]
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
    [Chest X-ray Portal Screen]             [ECG Heart Portal Screen]
                 │                                       │
                 ▼                                       ▼
        [POST /predict]                         [POST /predict_ecg]
                 │                                       │
                 ▼                                       ▼
        (FastAPI Server)                        (FastAPI Server)
       [xray_model.onnx]                        [ecg_model.onnx]
         (2 Classes)                             (4 Classes)
```

---

### 💻 1. Model Training
#### [NEW] [train_ecg.ipynb](file:///d:/Downloads/ai_project/ai_project/ai_project/train_ecg.ipynb)
A fully-featured, well-commented Jupyter Notebook that trains a 4-class ECG image classifier:
* **Preprocessing**: Resize to $224 \times 224$, convert to grayscale, denoise via Gaussian filtering, enhance contrast using CLAHE, and scale pixels.
* **Backbone Feature Extraction**: Load a pre-trained **InceptionV3** or **ResNet50** model, freeze lower layers, and extract 2048-dimensional feature vectors.
* **Feature Selection**: Apply Binary White Shark Optimization with Linear Discriminant Analysis (WSO-LDA) to select the top ~100 features.
* **HANN Model**: A hybrid multi-layer perceptron (Input $\to$ 256 $\to$ 128 $\to$ 64 $\to$ 4 classes) with Dropout (0.3) and Batch Normalization.
* **MOSHO weight optimization**: Spotted Hyena meta-heuristic search that seeks optimal weights to minimize cross-entropy loss and minimize the False Negative Rate (FNR) to prevent missing Myocardial Infarction.
* **Export**: Export the final model directly to ONNX format (`ecg_model.onnx`) with dynamic batching.

---

### 🐍 2. FastAPI Backend
#### [MODIFY] [main.py](file:///d:/Downloads/ai_project/ai_project/ai_project/backend/main.py)
* Load `ecg_model.onnx` alongside `xray_model.onnx` during startup.
* Define `preprocess_ecg_image(image: Image.Image)` matching the notebook preprocessing pipeline.
* Create a `POST /predict_ecg` endpoint returning:
  * Prediction label: `"Normal ECG"`, `"Abnormal Heartbeat"`, `"Myocardial Infarction Detected"`, or `"Post-MI History Detected"`.
  * Confidence score (percentage).
  * Probabilities dictionary for all 4 ECG classes.

---

### 🌐 3. Flutter Client

#### [MODIFY] [ai_service.dart](file:///d:/Downloads/ai_project/ai_project/ai_project/lib/services/ai_service.dart)
* Add `analyzeEcgImage(Uint8List imageBytes, String fileName)` web-compatible endpoint call.
* Add state variables: `String _lastEcgResult`, `double _ecgConfidence`.

#### [MODIFY] [home_screen.dart](file:///d:/Downloads/ai_project/ai_project/ai_project/lib/screens/home_screen.dart)
* Re-design the UI from a single X-ray form into a premium **Health Monitoring Hub**.
* Add diagnostic portal grid cards:
  1. **Lung Heath Screening** (Chest X-ray portal)
  2. **Cardiac Rhythm Analysis** (ECG Heart disease portal)
  3. **Clinical Location Finder** (Hospital Map finder)
* Incorporate visual charts or statistics demonstrating IoMT sensor connectivity.

#### [NEW] [ecg_screen.dart](file:///d:/Downloads/ai_project/ai_project/ai_project/lib/screens/ecg_screen.dart)
* A high-fidelity clinical screen dedicated to heart health analysis.
* Features dotted upload frames, local image previews (cross-platform memory representation), and standard loader animations while invoking the `/predict_ecg` endpoint.

#### [MODIFY] [results_screen.dart](file:///d:/Downloads/ai_project/ai_project/ai_project/lib/screens/results_screen.dart)
* Make it dynamic to parse multi-class diagnostic output.
* Customize results card themes:
  * **Normal**: Green theme, check icons, wellness guidelines.
  * **Abnormal / History of MI**: Amber theme, warning icons, non-emergency clinical appointment advice.
  * **Myocardial Infarction**: Deep crimson theme, emergency warning signs, prompt local critical care navigation card.

---

## 🧪 Verification Plan

### Automated Inference Testing
* Create dummy prediction tests in `backend/test_model.py` for both `/predict` and `/predict_ecg` to verify API routing and response contract.

### UI Integration Testing
* Open the web app on Google Chrome.
* Navigate to the **Cardiac Rhythm Analysis** tab.
* Upload an ECG image from `ecg_data/abnormal_heartbeat_ecg_images/` and press analyze.
* Confirm that the UI transitions to the **Results Screen** showing `Abnormal Heartbeat` with correct probabilities.
