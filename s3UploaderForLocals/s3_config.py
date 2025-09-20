"""
S3 Konfigürasyon Dosyası
AWS S3 bağlantı bilgileri ve ayarları
"""

# AWS S3 Konfigürasyonu
import os

# Environment variable'lardan al, yoksa default değerleri kullan
ACCESS_KEY = os.environ.get("AWS_ACCESS_KEY_ID", "AKIAYQNJS76JGOLLN5UJ")
SECRET_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY", "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")
BUCKET_NAME = os.environ.get("S3_BUCKET_NAME", "discord-bot-new")
REGION = os.environ.get("AWS_REGION", "eu-north-1")

# S3 Ayarları
S3_ENDPOINT_URL = None  # Varsayılan AWS endpoint kullanılacak
S3_USE_SSL = True
S3_SIGNATURE_VERSION = 's3v4'

# Yükleme Ayarları
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB
ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm'}

# Klasör Yapısı
UPLOAD_FOLDER_PREFIX = "comfyui-uploads/"
OUTPUT_FOLDER_PREFIX = "comfyui-outputs/"
