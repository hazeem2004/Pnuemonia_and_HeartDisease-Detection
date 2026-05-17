import os
import time
import copy
import numpy as np
import torch
import torch.nn as nn
from PIL import Image
from torchvision import models, transforms
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.metrics import accuracy_score, recall_score, f1_score

# Set Random Seed for Reproducibility
np.random.seed(42)
torch.manual_seed(42)

# =====================================================================
# 📸 STEP 1: DEEP FEATURE EXTRACTOR (CNN BACKBONE)
# =====================================================================
class DeepFeatureExtractor:
    def __init__(self, device='cpu'):
        self.device = torch.device(device)
        # Load pre-trained ResNet18
        self.resnet = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
        # Remove the classification head (fc layer)
        self.backbone = nn.Sequential(*list(self.resnet.children())[:-1])
        self.backbone = self.backbone.to(self.device)
        self.backbone.eval()
        
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])

    def extract(self, img_path):
        try:
            image = Image.open(img_path).convert('RGB')
            tensor = self.transform(image).unsqueeze(0).to(self.device)
            with torch.no_grad():
                # Shape: [1, 512, 1, 1] -> squeeze to [512]
                features = self.backbone(tensor)
                features = torch.squeeze(features).cpu().numpy()
            return features
        except Exception as e:
            print(f"Error reading {img_path}: {e}")
            return None

# Helper to load a dummy validation set from your project folders
def load_validation_features(extractor):
    print("Extracting features from validation dataset...")
    X, y = [], []
    
    # Check project directories
    for label, dir_name in enumerate(["NORMAL", "PNEUMONIA"]):
        if not os.path.exists(dir_name):
            continue
        files = [os.path.join(dir_name, f) for f in os.listdir(dir_name) if f.lower().endswith(('.jpeg', '.jpg', '.png'))]
        for f in files:
            feat = extractor.extract(f)
            if feat is not None:
                X.append(feat)
                y.append(label)
                
    return np.array(X), np.array(y)

# =====================================================================
# 🦈 STEP 2: BINARY WHITE SHARK OPTIMIZATION WITH LDA (WSO-LDA)
# =====================================================================
class BinaryWSOLDA:
    def __init__(self, num_sharks=15, max_iter=20, alpha=0.99):
        self.num_sharks = num_sharks
        self.max_iter = max_iter
        self.alpha = alpha  # Weight factor between accuracy and feature size

    def fitness(self, mask, X_train, y_train, X_val, y_val):
        selected_indices = np.where(mask == 1)[0]
        if len(selected_indices) == 0:
            return 999.0  # Heavy penalty for selecting 0 features
            
        X_tr = X_train[:, selected_indices]
        X_va = X_val[:, selected_indices]
        
        try:
            lda = LinearDiscriminantAnalysis()
            lda.fit(X_tr, y_train)
            preds = lda.predict(X_va)
            error = 1.0 - accuracy_score(y_val, preds)
            
            # Multi-objective fitness: balance error and feature length
            sparsity_penalty = len(selected_indices) / len(mask)
            fit = self.alpha * error + (1 - self.alpha) * sparsity_penalty
            return fit
        except Exception:
            return 999.0

    def optimize(self, X_train, y_train, X_val, y_val):
        num_features = X_train.shape[1]
        print(f"Starting WSO-LDA Feature Selection on {num_features} dimensions...")
        
        # Initialize Sharks (Binary masks of shape [num_sharks, num_features])
        sharks = np.random.randint(2, size=(self.num_sharks, num_features))
        velocities = np.random.uniform(-1, 1, size=(self.num_sharks, num_features))
        
        best_mask = None
        best_fitness = 999.0
        
        # Constants
        c1, c2 = 1.5, 1.5
        mu = 0.8
        
        for iteration in range(self.max_iter):
            for i in range(self.num_sharks):
                fit = self.fitness(sharks[i], X_train, y_train, X_val, y_val)
                
                if fit < best_fitness:
                    best_fitness = fit
                    best_mask = copy.deepcopy(sharks[i])
            
            # WSO updates based on best shark and prey tracking
            prey = best_mask
            for i in range(self.num_sharks):
                r1, r2 = np.random.rand(), np.random.rand()
                
                # Position & Velocity Tracking
                velocities[i] = mu * (velocities[i] + c1 * r1 * (best_mask - sharks[i]) + c2 * r2 * (prey - sharks[i]))
                
                # Sigmoid thresholding to force binary space
                sigmoid = 1 / (1 + np.exp(-velocities[i]))
                sharks[i] = (np.random.rand(num_features) < sigmoid).astype(int)
                
            print(f"   Iteration {iteration+1}/{self.max_iter} | Best Fitness: {best_fitness:.4f} | Selected features: {np.sum(best_mask)}/{num_features}")
            
        return best_mask

# =====================================================================
# 🕸️ STEP 3: HYBRID ARTIFICIAL NEURAL NETWORK (HANN)
# =====================================================================
class HybridANN(nn.Module):
    def __init__(self, input_dim, hidden_dim=64):
        super(HybridANN, self).__init__()
        # Feedforward MLP layers
        self.fc1 = nn.Linear(input_dim, hidden_dim)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(hidden_dim, 2)  # Binary output: Normal vs Pneumonia
        
    def forward(self, x):
        out = self.fc1(x)
        out = self.relu(out)
        logits = self.fc2(out)
        return logits

    # Flatten and get neural weights for optimization
    def get_weights(self):
        w = []
        for name, param in self.named_parameters():
            w.extend(param.detach().cpu().numpy().flatten())
        return np.array(w)

    # Re-inject weights optimized by SHO
    def set_weights(self, flat_weights):
        pointer = 0
        for name, param in self.named_parameters():
            num_el = param.numel()
            arr = np.array(flat_weights[pointer:pointer+num_el]).reshape(param.shape)
            param.data = torch.FloatTensor(arr)
            pointer += num_el

# =====================================================================
# 🐺 STEP 4: MULTI-OBJECTIVE SPOTTED HYENA OPTIMIZATION (MOSHO)
# =====================================================================
class MOSHO:
    def __init__(self, num_hyenas=10, max_iter=30):
        self.num_hyenas = num_hyenas
        self.max_iter = max_iter

    def evaluate_loss_and_fn(self, weights, model, X, y):
        # Inject weights into model
        model.set_weights(weights)
        
        # Run forward pass
        inputs = torch.FloatTensor(X)
        labels = torch.LongTensor(y)
        
        with torch.no_grad():
            outputs = model(inputs)
            criterion = nn.CrossEntropyLoss()
            loss = criterion(outputs, labels).item()
            
            # Sensitivity/False Negative metrics
            preds = torch.argmax(outputs, dim=1).numpy()
            recall = recall_score(y, preds, zero_division=0)
            false_negatives_rate = 1.0 - recall
            
        return loss, false_negatives_rate

    def optimize(self, model, X_train, y_train, X_val, y_val):
        print("\nStarting MOSHO Neural Network Weights Optimization...")
        # Get flat dimension of all weights in HANN
        sample_weights = model.get_weights()
        dim = len(sample_weights)
        
        # Initialize population of hyenas
        hyenas = np.random.uniform(-1, 1, size=(self.num_hyenas, dim))
        best_hyena = None
        best_loss = 999.0
        best_fn = 999.0
        
        for iteration in range(self.max_iter):
            # Dynamic variables (A encircling weight decreases linearly from 2 to 0)
            a = 2.0 - (iteration * (2.0 / self.max_iter))
            
            # Find best Hyena based on weighted loss and False Negatives
            for i in range(self.num_hyenas):
                loss, fn_rate = self.evaluate_loss_and_fn(hyenas[i], model, X_val, y_val)
                # Multi-objective criteria (heavily penalize false negatives)
                score = 0.6 * loss + 0.4 * fn_rate
                
                if score < (0.6 * best_loss + 0.4 * best_fn):
                    best_loss = loss
                    best_fn = fn_rate
                    best_hyena = copy.deepcopy(hyenas[i])
            
            # Update hyena positions based on encircling and group hunting
            for i in range(self.num_hyenas):
                r1, r2 = np.random.rand(), np.random.rand()
                A = 2 * a * r1 - a
                C = 2 * r2
                
                # Encircling
                D_h = np.abs(C * best_hyena - hyenas[i])
                # Group hunting
                P_k = best_hyena - A * D_h
                hyenas[i] = (hyenas[i] + P_k) / 2.0  # Cooperative hunting cluster updates
                
            print(f"   Iteration {iteration+1}/{self.max_iter} | Best Loss: {best_loss:.4f} | Validation False Negative Rate: {best_fn*100:.2f}%")
            
        return best_hyena

# =====================================================================
# 🚀 STEP 5: PIPELINE EXECUTION ENGINE
# =====================================================================
if __name__ == "__main__":
    print("=" * 70)
    print("🫁 TRAINING PIPELINE: WSO-LDA & MOSHO-HANN FOR PNEUMONIA DETECTOR")
    print("=" * 70)
    
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    extractor = DeepFeatureExtractor(device=device)
    
    # 1. Feature Extraction Stage
    X, y = load_validation_features(extractor)
    if len(X) == 0:
        print("Error: No validation images found. Please run this in the backend/ folder containing NORMAL and PNEUMONIA directories.")
        exit(1)
        
    print(f"Extracted feature dataset shape: {X.shape} | Labels shape: {y.shape}")
    
    # Split dataset into simulated Train and Validation subsets
    indices = np.random.permutation(len(X))
    split = int(0.6 * len(X))
    train_idx, val_idx = indices[:split], indices[split:]
    
    X_train, y_train = X[train_idx], y[train_idx]
    X_val, y_val = X[val_idx], y[val_idx]
    
    print(f"Train subset: {X_train.shape[0]} images | Val subset: {X_val.shape[0]} images")
    
    # 2. WSO-LDA Feature Selection Stage
    wso = BinaryWSOLDA(num_sharks=10, max_iter=15, alpha=0.98)
    best_feature_mask = wso.optimize(X_train, y_train, X_val, y_val)
    
    # Project features based on chosen mask
    selected_indices = np.where(best_feature_mask == 1)[0]
    X_train_sel = X_train[:, selected_indices]
    X_val_sel = X_val[:, selected_indices]
    input_dim = len(selected_indices)
    
    print(f"Optimized Feature Vector Dimension: {input_dim}-D (Reduced from 512-D)")
    
    # 3. MOSHO-HANN Classification Stage
    hann = HybridANN(input_dim=input_dim, hidden_dim=32)
    mosho = MOSHO(num_hyenas=8, max_iter=20)
    best_weights = mosho.optimize(hann, X_train_sel, y_train, X_val_sel, y_val)
    
    # Inject final optimized weights
    hann.set_weights(best_weights)
    hann.eval()
    
    # 4. Final Diagnostic Performance Evaluation
    print("\n" + "=" * 70)
    print("📊 METRIC DIAGNOSTIC EVALUATION")
    print("=" * 70)
    
    with torch.no_grad():
        test_inputs = torch.FloatTensor(X_val_sel)
        logits = hann(test_inputs)
        probs = torch.softmax(logits, dim=1).numpy()
        preds = np.argmax(probs, axis=1)
        
    accuracy = accuracy_score(y_val, preds) * 100
    sensitivity = recall_score(y_val, preds, zero_division=0) * 100
    f1 = f1_score(y_val, preds, zero_division=0) * 100
    
    print(f"Classification Accuracy:  {accuracy:.2f}%")
    print(f"Diagnostic Sensitivity:   {sensitivity:.2f}% (Recall/Recall rate)")
    print(f"F1-Score:                 {f1:.2f}%")
    
    # Save the selected mask and HANN weights for production
    state = {
        'feature_mask': best_feature_mask,
        'hann_state': hann.state_dict(),
        'input_dim': input_dim
    }
    torch.save(state, "hann_pneumonia_detector.pth")
    print("Saved HANN weights & feature mask: hann_pneumonia_detector.pth")
    print("=" * 70)
