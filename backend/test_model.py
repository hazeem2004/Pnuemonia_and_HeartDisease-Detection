import os
import time
import numpy as np
import onnxruntime as ort
from PIL import Image

# Directories containing test images
NORMAL_DIR = "NORMAL"
PNEUMONIA_DIR = "PNEUMONIA"
MODEL_PATH = "xray_model.onnx"

def preprocess_image(image_path: str) -> np.ndarray:
    """Preprocess image for model input - matches training/production preprocessing exactly"""
    # 1. Open and convert to RGB and resize to 224x224
    image = Image.open(image_path)
    img = image.convert('RGB')
    img = img.resize((224, 224))
    
    # 2. Convert to numpy array and scale to [0, 1]
    img_data = np.array(img).astype('float32')
    img_data /= 255.0
    
    # 3. Normalize with ImageNet mean and std
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    img_data = (img_data - mean) / std
    
    # 4. Transpose from (H, W, C) to (C, H, W)
    img_data = img_data.transpose(2, 0, 1)
    
    # 5. Add batch dimension -> (1, 3, 224, 224)
    img_data = np.expand_dims(img_data, axis=0)
    
    return img_data

def apply_softmax(logits: np.ndarray) -> np.ndarray:
    """Apply softmax to convert logits to probabilities"""
    exp_logits = np.exp(logits - np.max(logits))
    return exp_logits / np.sum(exp_logits)

def main():
    print("=" * 60)
    print("ONNX MODEL DIAGNOSTICS & EVALUATION")
    print("=" * 60)
    
    if not os.path.exists(MODEL_PATH):
        print(f"ERROR: Model not found at '{MODEL_PATH}'")
        return
        
    print(f"Loading ONNX Model: {MODEL_PATH}...")
    start_time = time.time()
    try:
        session = ort.InferenceSession(MODEL_PATH)
    except Exception as e:
        print(f"ERROR: Failed to load model: {e}")
        return
    load_duration = (time.time() - start_time) * 1000
    print(f"Model loaded successfully in {load_duration:.2f} ms")
    
    # Inspect inputs and outputs
    input_node = session.get_inputs()[0]
    output_node = session.get_outputs()[0]
    
    print("\n--- Model Metadata ---")
    print(f"Input Name:  {input_node.name}")
    print(f"Input Shape: {input_node.shape}")
    print(f"Input Type:  {input_node.type}")
    print(f"Output Name: {output_node.name}")
    print(f"Output Shape:{output_node.shape}")
    print(f"Output Type: {output_node.type}")
    
    # Class mappings: 0 -> Normal, 1 -> Pneumonia
    classes = ["Normal (No Pneumonia)", "Pneumonia Detected"]
    
    total_images = 0
    correct_predictions = 0
    inference_times = []
    
    results = []
    
    # Process both directories
    for label_idx, (dir_name, expected_class) in enumerate([(NORMAL_DIR, "Normal"), (PNEUMONIA_DIR, "Pneumonia")]):
        print(f"\n--- Evaluating {expected_class.upper()} Images ---")
        if not os.path.exists(dir_name):
            print(f"WARNING: Directory '{dir_name}' not found. Skipping.")
            continue
            
        files = [f for f in os.listdir(dir_name) if f.lower().endswith(('.jpeg', '.jpg', '.png'))]
        if not files:
            print(f"WARNING: No images found in '{dir_name}'.")
            continue
            
        for file_name in sorted(files, key=lambda x: int(x.split('_')[1].split('.')[0]) if '_' in x else x):
            img_path = os.path.join(dir_name, file_name)
            
            try:
                # Preprocess
                input_data = preprocess_image(img_path)
                
                # Run prediction and measure time
                inf_start = time.time()
                outputs = session.run([output_node.name], {input_node.name: input_data})
                inf_duration = (time.time() - inf_start) * 1000
                inference_times.append(inf_duration)
                
                # Get logits and apply softmax
                logits = outputs[0][0]
                probs = apply_softmax(logits)
                
                pred_idx = np.argmax(probs)
                confidence = probs[pred_idx] * 100
                
                is_correct = (pred_idx == label_idx)
                if is_correct:
                    correct_predictions += 1
                total_images += 1
                
                prediction_status = "[CORRECT]" if is_correct else "[WRONG]"
                
                print(f"{prediction_status} {file_name}:")
                print(f"   Prediction:  {classes[pred_idx]} ({confidence:.2f}%)")
                print(f"   Probabilities: Normal: {probs[0]*100:.2f}%, Pneumonia: {probs[1]*100:.2f}%")
                print(f"   Raw Logits:    [{logits[0]:.4f}, {logits[1]:.4f}]")
                print(f"   Inference Time: {inf_duration:.2f} ms")
                
                results.append({
                    "file_name": file_name,
                    "expected": expected_class,
                    "predicted": "Normal" if pred_idx == 0 else "Pneumonia",
                    "confidence": confidence,
                    "is_correct": is_correct,
                    "logits": logits.tolist(),
                    "probs": probs.tolist(),
                    "latency_ms": inf_duration
                })
                
            except Exception as e:
                print(f"ERROR processing {file_name}: {e}")
                
    # Summary of performance
    if total_images > 0:
        accuracy = (correct_predictions / total_images) * 100
        avg_latency = np.mean(inference_times)
        p95_latency = np.percentile(inference_times, 95)
        
        print("\n" + "=" * 60)
        print("FINAL PERFORMANCE EVALUATION SUMMARY")
        print("=" * 60)
        print(f"Total Evaluated Images:  {total_images}")
        print(f"Correct Predictions:     {correct_predictions} / {total_images}")
        print(f"Overall Model Accuracy:  {accuracy:.2f}%")
        print(f"Average Inference Latency: {avg_latency:.2f} ms")
        print(f"95th Percentile Latency: {p95_latency:.2f} ms")
        
        # Verify if 100% accuracy was achieved
        if accuracy == 100.0:
            print("\nPERFECT SCORE: The model achieved 100% accuracy on the local dataset!")
        else:
            print(f"\nThe model did not achieve a perfect score. Accuracy: {accuracy:.2f}%")
            
        print("=" * 60)
    else:
        print("\nERROR: No images were processed. Check image directories.")

if __name__ == "__main__":
    main()
