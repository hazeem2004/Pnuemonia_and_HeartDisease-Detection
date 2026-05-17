# PneumoAI Model Training & Optimization Guide

This guide describes how to run the newly created PyTorch training pipeline ([train_model.py](file:///d:/Downloads/ai_project/ai_project/ai_project/backend/train_model.py)) to retrain and improve your pneumonia chest X-ray model, and then export it back as a fully compatible `xray_model.onnx`.

---

## 📂 1. Organizing Your Dataset

Your training script expects the dataset to be organized into splits. Most chest X-ray datasets (including the popular Kaggle Pneumonia dataset) are structured this way by default:

```text
chest_xray/
├── train/
│   ├── NORMAL/
│   │   ├── normal_img_1.jpeg
│   │   └── ...
│   └── PNEUMONIA/
│       ├── pneumonia_img_1.jpeg
│       └── ...
└── val/  (or test/)
    ├── NORMAL/
    │   ├── normal_img_99.jpeg
    │   └── ...
    └── PNEUMONIA/
        ├── pneumonia_img_99.jpeg
        └── ...
```

---

## ⚡ Option A: Running on Google Colab (Highly Recommended - Free GPU!)

Since training deep learning models (like ResNets) on a CPU can be slow, running it on Google Colab with a free T4 GPU is the fastest option.

### Steps:
1. Open Google Colab: [colab.research.google.com](https://colab.research.google.com)
2. Create a new notebook.
3. Change the runtime to GPU:
   * **Runtime** → **Change runtime type** → Select **T4 GPU** under Hardware accelerator → click **Save**.
4. Zip your dataset folder (`chest_xray.zip`) and upload it to Colab's file storage (click the folder icon on the left sidebar and upload).
5. Unzip your dataset inside the notebook:
   ```bash
   !unzip -q chest_xray.zip
   ```
6. Upload the training script [train_model.py](file:///d:/Downloads/ai_project/ai_project/ai_project/backend/train_model.py) to Colab's file system.
7. Run the training script:
   ```bash
   !python train_model.py --data_dir chest_xray --epochs 10 --batch_size 32 --model_name resnet18 --export_path xray_model.onnx
   ```
8. Once training is complete, the script will output a file named `xray_model.onnx` in your Colab files. Simply download it and replace the existing `xray_model.onnx` in your `backend/` folder!

---

## ⚡ Option B: Running on Kaggle Notebooks (Free GPU!)

Kaggle already has the chest X-ray pneumonia dataset hosted, so you do not even need to upload your images!

### Steps:
1. Open Kaggle and search for the dataset: **Chest X-Ray Images (Pneumonia)** by Paul Mooney.
2. Click **New Notebook** on the dataset page.
3. In the right sidebar under **Settings**, toggle **Accelerator** to **GPU T4 x2** (or GPU P100) and turn on **Internet**.
4. Copy the entire contents of [train_model.py](file:///d:/Downloads/ai_project/ai_project/ai_project/backend/train_model.py) and paste them into a cell in your Kaggle Notebook.
5. Add the following run commands in a new cell:
   ```python
   # Run the script pointing to Kaggle's input dataset path
   !python -c "import train_model" --data_dir /kaggle/input/chest-xray-pneumonia/chest_xray/chest_xray --epochs 10 --batch_size 32 --model_name resnet18 --export_path xray_model.onnx
   ```
6. Download the generated `xray_model.onnx` output file from your Kaggle notebook, and save it in your project's `backend/` folder!

---

## 💻 Option C: Running Locally

If you have a local machine with a GPU (NVIDIA CUDA) or a capable CPU, you can run training locally.

### Steps:
1. Open your terminal in the `backend/` folder.
2. Activate your virtual environment:
   ```bash
   # Windows PowerShell
   .\venv\Scripts\Activate.ps1
   ```
3. Install the machine learning training requirements:
   ```bash
   pip install -r requirements_train.txt
   ```
4. Place your dataset directory inside the backend folder (e.g., in a folder named `dataset`).
5. Run the training command:
   ```bash
   python train_model.py --data_dir ./dataset --epochs 10 --batch_size 16 --model_name resnet18 --export_path xray_model.onnx
   ```
6. The script will automatically train, select the highest performing model, and overwrite the existing `xray_model.onnx` with the improved model.

---

## 🔍 Model Tuning & Customization

The script supports arguments to customize model training:

* **`--model_name`**: Choose between `resnet18` (lighter, faster) or `resnet50` (deeper, captures complex details).
* **`--epochs`**: Change training iterations. E.g., `--epochs 15`.
* **`--batch_size`**: Change batch sizes (reduce if you run out of GPU memory). E.g., `--batch_size 16`.
* **`--lr`**: Set the learning rate. E.g., `--lr 0.0005`.
