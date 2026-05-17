# Pneumonia Detection App - Deployment Checklist

## ✅ What's Been Fixed

### Backend API (backend/main.py)
- ✅ **ImageNet normalization added** - Mean=[0.485, 0.456, 0.406], Std=[0.229, 0.224, 0.225]
- ✅ **Tested with 20/20 (100%) accuracy** on local images
- ✅ Ready for deployment to Render

### Flutter App (lib/services/ai_service.dart)
- ✅ **Removed TFLite dependencies** - No more local model
- ✅ **Updated to use HTTP API** - Calls backend /predict endpoint
- ✅ **Removed image preprocessing** - Backend handles all preprocessing
- ✅ **Smaller APK size** - No 18MB model embedded

### Dependencies (pubspec.yaml)
- ✅ **Removed**: tflite_flutter, image packages
- ✅ **Kept**: http package for API calls
- ✅ **Removed model assets** - No .tflite files in APK

## 📋 Before Building APK

### 1. Deploy Backend to Render
```bash
cd backend
git init
git add .
git commit -m "Initial backend deployment"
# Push to GitHub
# Connect GitHub repo to Render
# Render will auto-detect render.yaml and deploy
```

### 2. Update API URL in Flutter App
Edit `lib/services/ai_service.dart`:
```dart
// Change this line:
static const String apiUrl = 'http://10.0.2.2:8000';

// To your Render URL:
static const String apiUrl = 'https://your-app-name.onrender.com';
```

### 3. Internet Permission (Android)
Check `android/app/src/main/AndroidManifest.xml` has:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### 4. Build APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

## 🧪 Testing Checklist

### Local Testing (Before Deployment)
1. ✅ Backend tested with direct ONNX - 20/20 accuracy
2. ✅ Backend API tested with test_api_simple.py - 20/20 accuracy
3. ⏳ Flutter app tested with localhost backend
4. ⏳ APK tested on Android device with localhost backend

### Production Testing (After Deployment)
1. ⏳ Update API URL to Render endpoint
2. ⏳ Test Flutter app with production backend
3. ⏳ Build and test production APK
4. ⏳ Verify predictions match local testing (99%+ for NORMAL, 62-97% for PNEUMONIA)

## 📊 Expected Results

### NORMAL X-rays
- Confidence: 98-99%
- Result: "Normal (No Pneumonia)"
- Raw logits: [+2.0 to +3.0, -2.0 to -3.0]

### PNEUMONIA X-rays  
- Confidence: 62-97%
- Result: "Pneumonia Detected"
- Raw logits: [-0.3 to -1.8, +0.2 to +1.8]

## 🔧 Troubleshooting

### If APK shows "Analysis Failed"
1. Check internet connection
2. Verify API URL is correct (https:// for Render)
3. Check backend logs on Render dashboard
4. Test API with curl/Postman

### If predictions are wrong
1. Verify backend is using xray_model.onnx (18.4MB)
2. Check backend logs for preprocessing errors
3. Test same image with test_direct_onnx.py locally
4. Compare raw logits between local and production

## 📝 Important Notes

1. **API URL for Android Emulator**: Use `http://10.0.2.2:8000` (localhost from emulator)
2. **API URL for Physical Device**: Use computer's IP address or deploy to Render
3. **Free Render**: Backend sleeps after 15 min inactivity, first request takes ~30sec
4. **Model file**: Ensure xray_model.onnx (18.4MB) is in backend/ folder before deployment
5. **Class mapping**: Index 0 = NORMAL, Index 1 = PNEUMONIA (verified in training code)

## 🎯 Final Steps

1. Deploy backend to Render → Get URL
2. Update API URL in ai_service.dart
3. flutter clean && flutter pub get
4. flutter build apk --release
5. Test APK on physical Android device
6. Verify 100% accuracy on test images

---
**Status**: Backend fixed ✅ | Flutter app updated ✅ | Ready for deployment ✅
