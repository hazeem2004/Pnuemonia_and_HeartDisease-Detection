import os
import time
import copy
import numpy as np
import torch
import torch.nn as nn
from PIL import Image, ImageOps, ImageFilter
from torch.utils.data import Dataset, DataLoader
from torchvision import models, transforms
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.metrics import accuracy_score, recall_score
import onnxruntime as ort

# Set Random Seeds for reproducibility
np.random.seed(42)
torch.manual_seed(42)

# Global variables
DATA_DIR = "../ecg_data"
TEST_DIR = "../ECG-Test-Images"
MODEL_NAME = "ecg_model.onnx"

# Verify folders
if not os.path.exists(DATA_DIR):
    DATA_DIR = "./ecg_data"
if not os.path.exists(TEST_DIR):
    TEST_DIR = "./ECG-Test-Images"

print(f"Training folder resolved to: {os.path.abspath(DATA_DIR)}")
print(f"Test folder resolved to: {os.path.abspath(TEST_DIR)}")

# =====================================================================
# 🖼️ STAGE 2: PREPROCESSING (Grayscale, Gaussian, Equalization)
# =====================================================================
def preprocess_ecg_image(image_path):
    try:
        img = Image.open(image_path)
        
        # 1. Convert to Grayscale
        gray = img.convert('L')
        
        # 2. Enhance contrast using Histogram Equalization (PIL fallback for CLAHE)
        equalized = ImageOps.equalize(gray)
        
        # 3. Denoise with Gaussian Blur (matches blurred grid removal)
        blurred = equalized.filter(ImageFilter.GaussianBlur(radius=1.0))
        
        # 4. Resize to 224x224
        resized = blurred.resize((224, 224))
        
        # Convert back to 3-channel RGB for ResNet compatibility
        rgb_enhanced = Image.merge("RGB", [resized, resized, resized])
        
        return np.array(rgb_enhanced)
    except Exception as e:
        print(f"   Preprocessing error on {image_path}: {e}")
        return None

# Custom PyTorch Dataset
class ECGDataset(Dataset):
    def __init__(self, data_dir, transform=None):
        self.data_dir = data_dir
        self.transform = transform
        self.classes = [
            "normal_ecg_images",
            "abnormal_heartbeat_ecg_images",
            "myocardial_infarction_ecg_images",
            "post_mi_history_ecg_images"
        ]
        self.image_paths = []
        self.labels = []
        
        for idx, cls in enumerate(self.classes):
            cls_path = os.path.join(data_dir, cls)
            if not os.path.exists(cls_path):
                continue
            
            for filename in os.listdir(cls_path):
                if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
                    self.image_paths.append(os.path.join(cls_path, filename))
                    self.labels.append(idx)

    def __len__(self):
        return len(self.image_paths)

    def __getitem__(self, idx):
        img_path = self.image_paths[idx]
        label = self.labels[idx]
        
        preprocessed = preprocess_ecg_image(img_path)
        if preprocessed is None:
            preprocessed = np.zeros((224, 224, 3), dtype=np.uint8)
            
        pil_img = Image.fromarray(preprocessed)
        if self.transform:
            pil_img = self.transform(pil_img)
            
        return pil_img, label

# =====================================================================
# 📸 STAGE 3: FEATURE EXTRACTION (ResNet18)
# =====================================================================
class FeatureExtractor:
    def __init__(self):
        self.model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
        self.model.fc = nn.Identity() # Remove output head (Output dimension: 512)
        self.model.eval()
        
        self.transform = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])

    def extract_features(self, dataset):
        loader = DataLoader(dataset, batch_size=32, shuffle=False)
        features, labels = [], []
        with torch.no_grad():
            for inputs, targets in loader:
                feats = self.model(inputs)
                features.append(feats.numpy())
                labels.append(targets.numpy())
        return np.concatenate(features, axis=0), np.concatenate(labels, axis=0)

# =====================================================================
# 🦈 STAGE 4: FEATURE SELECTION (WSO-LDA)
# =====================================================================
class BinaryWSOLDA:
    def __init__(self, num_sharks=10, max_iter=8, alpha=0.98):
        self.num_sharks = num_sharks
        self.max_iter = max_iter
        self.alpha = alpha

    def fitness(self, mask, X_train, y_train, X_val, y_val):
        selected = np.where(mask == 1)[0]
        if len(selected) == 0:
            return 999.0
        X_tr = X_train[:, selected]
        X_va = X_val[:, selected]
        
        try:
            lda = LinearDiscriminantAnalysis()
            lda.fit(X_tr, y_train)
            preds = lda.predict(X_va)
            error = 1.0 - accuracy_score(y_val, preds)
            sparsity = len(selected) / len(mask)
            return self.alpha * error + (1 - self.alpha) * sparsity
        except Exception:
            return 999.0

    def optimize(self, X_train, y_train, X_val, y_val):
        num_features = X_train.shape[1]
        print(f"Starting Binary White Shark Optimization over {num_features}-D deep features...")
        
        sharks = np.random.randint(2, size=(self.num_sharks, num_features))
        velocities = np.random.uniform(-1, 1, size=(self.num_sharks, num_features))
        
        best_mask = None
        best_fitness = 999.0
        
        for iteration in range(self.max_iter):
            for i in range(self.num_sharks):
                fit = self.fitness(sharks[i], X_train, y_train, X_val, y_val)
                if fit < best_fitness:
                    best_fitness = fit
                    best_mask = copy.deepcopy(sharks[i])
                    
            prey = best_mask
            for i in range(self.num_sharks):
                r1, r2 = np.random.rand(), np.random.rand()
                velocities[i] = 0.8 * (velocities[i] + 1.5 * r1 * (best_mask - sharks[i]) + 1.5 * r2 * (prey - sharks[i]))
                sigmoid = 1 / (1 + np.exp(-velocities[i]))
                sharks[i] = (np.random.rand(num_features) < sigmoid).astype(int)
                
            print(f"   WSO Iteration {iteration+1}/{self.max_iter} | Best Fitness: {best_fitness:.4f} | Selected features: {np.sum(best_mask)}/{num_features}")
        return best_mask

# =====================================================================
# 🕸️ STAGE 5: HYBRID NEURAL NETWORK (HANN) & MOSHO
# =====================================================================
class HybridANN(nn.Module):
    def __init__(self, input_dim):
        super(HybridANN, self).__init__()
        self.network = nn.Sequential(
            nn.Linear(input_dim, 256),
            nn.BatchNorm1d(256),
            nn.ReLU(),
            nn.Dropout(0.2),
            
            nn.Linear(256, 128),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            nn.Dropout(0.2),
            
            nn.Linear(128, 64),
            nn.BatchNorm1d(64),
            nn.ReLU(),
            
            nn.Linear(64, 4)
        )

    def forward(self, x):
        return self.network(x)

    def get_weights(self):
        w = []
        for param in self.parameters():
            w.extend(param.detach().cpu().numpy().flatten())
        return np.array(w)

    def set_weights(self, flat_weights):
        pointer = 0
        for param in self.parameters():
            num_el = param.numel()
            arr = np.array(flat_weights[pointer:pointer+num_el]).reshape(param.shape)
            param.data = torch.FloatTensor(arr)
            pointer += num_el

class MOSHO:
    def __init__(self, num_hyenas=8, max_iter=10):
        self.num_hyenas = num_hyenas
        self.max_iter = max_iter

    def evaluate(self, weights, model, X, y):
        model.set_weights(weights)
        model.eval()
        inputs = torch.FloatTensor(X)
        labels = torch.LongTensor(y)
        with torch.no_grad():
            outputs = model(inputs)
            criterion = nn.CrossEntropyLoss()
            loss = criterion(outputs, labels).item()
            preds = torch.argmax(outputs, dim=1).numpy()
            fnr = 1.0 - recall_score(y, preds, average='macro', zero_division=0)
        return loss, fnr

    def optimize(self, model, X_train, y_train, X_val, y_val):
        print("Starting Multi-Objective Spotted Hyena Optimization on HANN parameters...")
        base_weights = model.get_weights()
        dim = len(base_weights)
        
        # Initialize hyenas as local perturbations of the high-accuracy pre-trained base weights
        hyenas = np.zeros((self.num_hyenas, dim))
        hyenas[0] = base_weights  # Keep the best pre-trained baseline intact
        for i in range(1, self.num_hyenas):
            hyenas[i] = base_weights + np.random.normal(0, 0.015, size=dim)
            
        best_hyena = copy.deepcopy(base_weights)
        # Initialize best score with baseline weights
        best_loss, best_fnr = self.evaluate(base_weights, model, X_val, y_val)
        best_score = 0.5 * best_loss + 0.5 * best_fnr
        
        for iteration in range(self.max_iter):
            a = 2.0 - (iteration * (2.0 / self.max_iter))
            for i in range(self.num_hyenas):
                loss, fnr = self.evaluate(hyenas[i], model, X_val, y_val)
                score = 0.5 * loss + 0.5 * fnr
                if score < best_score:
                    best_score = score
                    best_hyena = copy.deepcopy(hyenas[i])
                    
            for i in range(self.num_hyenas):
                r1, r2 = np.random.rand(), np.random.rand()
                A = 2 * a * r1 - a
                C = 2 * r2
                D_h = np.abs(C * best_hyena - hyenas[i])
                P_k = best_hyena - A * D_h
                hyenas[i] = (hyenas[i] + P_k) / 2.0
                
            print(f"   MOSHO Iteration {iteration+1}/{self.max_iter} | Best Pareto Score: {best_score:.4f}")
        return best_hyena

# =====================================================================
# 📦 UNIFIED PIPELINE WRAPPER FOR ONNX EXPORT
# =====================================================================
class CompleteECGClassifierONNX(nn.Module):
    def __init__(self, cnn_backbone, feature_mask, hann_classifier):
        super(CompleteECGClassifierONNX, self).__init__()
        self.cnn = cnn_backbone
        self.register_buffer('mask', torch.LongTensor(np.where(feature_mask == 1)[0]))
        self.hann = hann_classifier

    def forward(self, x):
        features = self.cnn(x)
        selected = torch.index_select(features, 1, self.mask)
        logits = self.hann(selected)
        return logits

# =====================================================================
# 🚀 MAIN PIPELINE RUNNER
# =====================================================================
def main():
    print("="*80)
    print("TRAINING PIPELINE STARTED: INCEPTION/RESNET + WSO-LDA + MOSHO-HANN")
    print("="*80)
    
    if not os.path.exists(DATA_DIR):
        print(f"Error: {DATA_DIR} folder not found! Please check data path.")
        return

    # 1. Feature Extraction
    extractor = FeatureExtractor()
    dataset = ECGDataset(data_dir=DATA_DIR, transform=extractor.transform)
    X, y = extractor.extract_features(dataset)
    print(f"Features extracted successfully! Shape: {X.shape}")
    
    # Shuffle & Split
    shuffled_indices = np.random.permutation(len(X))
    split = int(0.8 * len(X))
    X_train, y_train = X[shuffled_indices[:split]], y[shuffled_indices[:split]]
    X_val, y_val = X[shuffled_indices[split:]], y[shuffled_indices[split:]]

    # 2. Binary WSO-LDA Feature Selection
    wso = BinaryWSOLDA()
    best_mask = wso.optimize(X_train, y_train, X_val, y_val)
    selected_feats = np.where(best_mask == 1)[0]
    input_dim = len(selected_feats)
    print(f"Feature compression complete: {input_dim}-D features selected.")

    # 3. HANN Backprop + MOSHO Optimization
    X_train_sel = X_train[:, selected_feats]
    X_val_sel = X_val[:, selected_feats]
    
    hann = HybridANN(input_dim=input_dim)
    
    # Pre-train via fast Adam optimizer to converge HANN rapidly
    print("Fast-training HANN classifier via backpropagation...")
    optimizer = torch.optim.Adam(hann.parameters(), lr=0.003)
    criterion = nn.CrossEntropyLoss()
    
    hann.train()
    for epoch in range(120):
        optimizer.zero_grad()
        outputs = hann(torch.FloatTensor(X_train_sel))
        loss = criterion(outputs, torch.LongTensor(y_train))
        loss.backward()
        optimizer.step()
        
    # Meta-heuristic Weight Tuning via Spotted Hyena encircling
    mosho = MOSHO()
    best_weights = mosho.optimize(hann, X_train_sel, y_train, X_val_sel, y_val)
    hann.set_weights(best_weights)
    hann.eval()
    
    # Evaluate Validation Performance
    with torch.no_grad():
        val_logits = hann(torch.FloatTensor(X_val_sel))
        val_preds = torch.argmax(val_logits, dim=1).numpy()
    val_acc = accuracy_score(y_val, val_preds) * 100
    print(f"\nHANN Validation Accuracy: {val_acc:.2f}%")

    # 4. EXPORT TO ONNX
    print("\nPackaging unified pipeline and exporting to ONNX...")
    combined_model = CompleteECGClassifierONNX(extractor.model, best_mask, hann)
    combined_model.eval()
    
    dummy_input = torch.randn(1, 3, 224, 224)
    
    # Export to root AND backend folder for convenience
    torch.onnx.export(
        combined_model,
        dummy_input,
        MODEL_NAME,
        export_params=True,
        opset_version=15,
        do_constant_folding=True,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input": {0: "batch"}},
    )
    
    # Copy to backend directory
    import shutil
    try:
        shutil.copy(MODEL_NAME, f"./{MODEL_NAME}")
        shutil.copy(MODEL_NAME, f"../{MODEL_NAME}")
        print("ONNX model saved in server root and backend folder successfully!")
    except Exception as e:
        print(f"   ONNX copy notice: {e}")

    # =====================================================================
    # 🧪 STAGE 6: TEST SUITE EVALUATION (ECG-Test-Images)
    # =====================================================================
    print("\n" + "="*80)
    print("EVALUATING ONNX MODEL ON TEST DATASET: ECG-Test-Images")
    print("="*80)
    
    if not os.path.exists(TEST_DIR):
        print(f"Test directory not found: {TEST_DIR}")
        return

    # Load ONNX Session
    session = ort.InferenceSession(MODEL_NAME)
    
    test_files = [f for f in os.listdir(TEST_DIR) if f.lower().endswith(('.jpg', '.png', '.jpeg'))]
    if not test_files:
        print("No test images found in ECG-Test-Images.")
        return

    # Mappings
    classes = ["Normal ECG", "Abnormal Heartbeat", "Myocardial Infarction Detected", "Post-MI History Detected"]
    
    correct = 0
    total = 0
    
    print("\n| Image File Name | Expected Diagnosis | Predicted Diagnosis | Confidence | Status |")
    print("|" + "-"*40 + "|" + "-"*25 + "|" + "-"*30 + "|" + "-"*12 + "|" + "-"*10 + "|")
    
    for filename in sorted(test_files):
        img_path = os.path.join(TEST_DIR, filename)
        
        # 1. Resolve expected class based on filename
        lower_name = filename.lower()
        if "norm" in lower_name:
            expected_idx = 0
        elif "block" in lower_name or "abnormal" in lower_name:
            expected_idx = 1
        elif "stemi" in lower_name or "infarction" in lower_name or "mi" in lower_name:
            expected_idx = 2
        elif "history" in lower_name or "post" in lower_name:
            expected_idx = 3
        else:
            # Fallback
            expected_idx = 1
            
        expected_class = classes[expected_idx]

        # 2. Run Preprocessing matching API exactly
        img = preprocess_ecg_image(img_path)
        if img is None:
            continue
            
        img_data = img.astype('float32') / 255.0
        mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
        std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
        img_data = (img_data - mean) / std
        img_data = img_data.transpose(2, 0, 1)
        img_data = np.expand_dims(img_data, axis=0)

        # 3. ONNX Inference
        input_name = session.get_inputs()[0].name
        output_name = session.get_outputs()[0].name
        
        outputs = session.run([output_name], {input_name: img_data})
        logits = outputs[0][0]
        
        # Softmax
        exp_l = np.exp(logits - np.max(logits))
        probs = exp_l / np.sum(exp_l)
        
        pred_idx = np.argmax(probs)
        confidence = probs[pred_idx] * 100
        predicted_class = classes[pred_idx]
        
        is_correct = (pred_idx == expected_idx)
        if is_correct:
            correct += 1
        total += 1
        
        status = "CORRECT" if is_correct else "WRONG"
        
        print(f"| {filename:<38} | {expected_class:<23} | {predicted_class:<28} | {confidence:6.2f}% | {status:<8} |")

    accuracy = (correct / total) * 100
    print("\n" + "="*80)
    print("FINAL MODEL PERFORMANCE REPORT ON ECG-Test-Images")
    print("="*80)
    print(f"Total Test Instances: {total}")
    print(f"Correct Predictions:  {correct} / {total}")
    print(f"Final Model Accuracy: {accuracy:.2f}%")
    print("="*80 + "\n")

if __name__ == "__main__":
    main()
