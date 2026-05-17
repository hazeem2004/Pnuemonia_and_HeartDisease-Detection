# Pneumonia Detection API

FastAPI backend for pneumonia detection using ONNX model.

## Local Testing

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Copy your model:
```bash
copy ..\xray_model.onnx .
```

3. Run server:
```bash
python main.py
```

4. Test API:
- Open browser: http://localhost:8000
- API docs: http://localhost:8000/docs
- Test upload: http://localhost:8000/docs#/default/predict_predict_post

## Deploy to Render

1. Create new GitHub repository
2. Push this backend folder to GitHub
3. Connect to Render:
   - Go to https://render.com
   - New → Web Service
   - Connect your GitHub repo
   - Select Python environment
   - Render will auto-detect settings from render.yaml

4. **Important**: Upload `xray_model.onnx` to the backend folder before deploying

## API Endpoints

### POST /predict
Upload X-ray image for prediction.

**Request:**
- Content-Type: multipart/form-data
- file: Image file (JPEG/PNG)

**Response:**
```json
{
  "success": true,
  "result": "Pneumonia Detected",
  "confidence": 87.54,
  "probabilities": {
    "normal": 12.46,
    "pneumonia": 87.54
  },
  "raw_output": [-1.234, 2.567]
}
```

### GET /health
Check API health status.

### GET /
API information and endpoints.
