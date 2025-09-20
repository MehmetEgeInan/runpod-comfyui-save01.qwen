"""
S3 Uploader Sınıfı
AWS S3'e dosya yükleme ve yönetim işlemleri
"""

import boto3
import os
import mimetypes
from datetime import datetime
from botocore.exceptions import ClientError, NoCredentialsError
from .s3_config import (
    ACCESS_KEY, SECRET_KEY, BUCKET_NAME, REGION,
    S3_ENDPOINT_URL, S3_USE_SSL, S3_SIGNATURE_VERSION,
    MAX_FILE_SIZE, ALLOWED_EXTENSIONS,
    UPLOAD_FOLDER_PREFIX, OUTPUT_FOLDER_PREFIX
)

class S3Uploader:
    def __init__(self):
        """S3 Uploader sınıfını başlat"""
        try:
            self.s3_client = boto3.client(
                's3',
                aws_access_key_id=ACCESS_KEY,
                aws_secret_access_key=SECRET_KEY,
                region_name=REGION,
                endpoint_url=S3_ENDPOINT_URL,
                use_ssl=S3_USE_SSL,
                config=boto3.session.Config(signature_version=S3_SIGNATURE_VERSION)
            )
            self.bucket_name = BUCKET_NAME
            print(f"S3 Uploader başlatıldı - Bucket: {self.bucket_name}, Region: {REGION}")
        except Exception as e:
            print(f"S3 bağlantı hatası: {e}")
            self.s3_client = None

    def upload_file(self, local_file_path, s3_key=None, folder_type="upload"):
        """
        Yerel dosyayı S3'e yükle
        
        Args:
            local_file_path (str): Yerel dosya yolu
            s3_key (str): S3'teki dosya adı (opsiyonel)
            folder_type (str): "upload" veya "output"
            
        Returns:
            dict: Yükleme sonucu
        """
        if not self.s3_client:
            return {"status": "error", "message": "S3 bağlantısı kurulamadı"}

        if not os.path.exists(local_file_path):
            return {"status": "error", "message": f"Dosya bulunamadı: {local_file_path}"}

        # Dosya boyutunu kontrol et
        file_size = os.path.getsize(local_file_path)
        if file_size > MAX_FILE_SIZE:
            return {"status": "error", "message": f"Dosya çok büyük: {file_size} bytes (Max: {MAX_FILE_SIZE})"}

        # Dosya uzantısını kontrol et
        file_ext = os.path.splitext(local_file_path)[1].lower()
        if file_ext not in ALLOWED_EXTENSIONS:
            return {"status": "error", "message": f"Desteklenmeyen dosya türü: {file_ext}"}

        try:
            # S3 key oluştur
            if not s3_key:
                filename = os.path.basename(local_file_path)
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                s3_key = f"{UPLOAD_FOLDER_PREFIX if folder_type == 'upload' else OUTPUT_FOLDER_PREFIX}{timestamp}_{filename}"

            # MIME type belirle
            content_type, _ = mimetypes.guess_type(local_file_path)
            if not content_type:
                content_type = 'application/octet-stream'

            # Dosyayı yükle
            extra_args = {
                'ContentType': content_type,
                'Metadata': {
                    'uploaded_at': datetime.now().isoformat(),
                    'source': 'comfyui-runpod'
                }
            }

            self.s3_client.upload_file(
                local_file_path,
                self.bucket_name,
                s3_key,
                ExtraArgs=extra_args
            )

            # S3 URL oluştur
            s3_url = f"https://{self.bucket_name}.s3.{REGION}.amazonaws.com/{s3_key}"

            return {
                "status": "success",
                "message": "Dosya başarıyla yüklendi",
                "s3_key": s3_key,
                "s3_url": s3_url,
                "file_size": file_size,
                "content_type": content_type
            }

        except NoCredentialsError:
            return {"status": "error", "message": "AWS kimlik bilgileri bulunamadı"}
        except ClientError as e:
            return {"status": "error", "message": f"AWS S3 hatası: {str(e)}"}
        except Exception as e:
            return {"status": "error", "message": f"Yükleme hatası: {str(e)}"}

    def upload_multiple_files(self, file_paths, folder_type="upload"):
        """
        Birden fazla dosyayı S3'e yükle
        
        Args:
            file_paths (list): Yerel dosya yolları listesi
            folder_type (str): "upload" veya "output"
            
        Returns:
            list: Yükleme sonuçları listesi
        """
        results = []
        for file_path in file_paths:
            result = self.upload_file(file_path, folder_type=folder_type)
            results.append({
                "file_path": file_path,
                "result": result
            })
        return results

    def delete_file(self, s3_key):
        """
        S3'ten dosya sil
        
        Args:
            s3_key (str): S3'teki dosya anahtarı
            
        Returns:
            dict: Silme sonucu
        """
        if not self.s3_client:
            return {"status": "error", "message": "S3 bağlantısı kurulamadı"}

        try:
            self.s3_client.delete_object(Bucket=self.bucket_name, Key=s3_key)
            return {"status": "success", "message": f"Dosya silindi: {s3_key}"}
        except ClientError as e:
            return {"status": "error", "message": f"S3 silme hatası: {str(e)}"}
        except Exception as e:
            return {"status": "error", "message": f"Silme hatası: {str(e)}"}

    def list_files(self, prefix="", max_keys=100):
        """
        S3'teki dosyaları listele
        
        Args:
            prefix (str): Dosya öneki
            max_keys (int): Maksimum dosya sayısı
            
        Returns:
            dict: Dosya listesi
        """
        if not self.s3_client:
            return {"status": "error", "message": "S3 bağlantısı kurulamadı"}

        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix,
                MaxKeys=max_keys
            )

            files = []
            if 'Contents' in response:
                for obj in response['Contents']:
                    files.append({
                        "key": obj['Key'],
                        "size": obj['Size'],
                        "last_modified": obj['LastModified'].isoformat(),
                        "url": f"https://{self.bucket_name}.s3.{REGION}.amazonaws.com/{obj['Key']}"
                    })

            return {
                "status": "success",
                "files": files,
                "count": len(files)
            }

        except ClientError as e:
            return {"status": "error", "message": f"S3 listeleme hatası: {str(e)}"}
        except Exception as e:
            return {"status": "error", "message": f"Listeleme hatası: {str(e)}"}

    def get_file_url(self, s3_key, expires_in=3600):
        """
        S3 dosyası için geçici URL oluştur
        
        Args:
            s3_key (str): S3'teki dosya anahtarı
            expires_in (int): URL geçerlilik süresi (saniye)
            
        Returns:
            dict: URL sonucu
        """
        if not self.s3_client:
            return {"status": "error", "message": "S3 bağlantısı kurulamadı"}

        try:
            url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': s3_key},
                ExpiresIn=expires_in
            )
            return {
                "status": "success",
                "url": url,
                "expires_in": expires_in
            }
        except ClientError as e:
            return {"status": "error", "message": f"URL oluşturma hatası: {str(e)}"}
        except Exception as e:
            return {"status": "error", "message": f"URL hatası: {str(e)}"}

    def test_connection(self):
        """
        S3 bağlantısını test et
        
        Returns:
            dict: Test sonucu
        """
        if not self.s3_client:
            return {"status": "error", "message": "S3 bağlantısı kurulamadı"}

        try:
            # Bucket'ın varlığını kontrol et
            self.s3_client.head_bucket(Bucket=self.bucket_name)
            return {
                "status": "success",
                "message": f"S3 bağlantısı başarılı - Bucket: {self.bucket_name}",
                "bucket": self.bucket_name,
                "region": REGION
            }
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == '404':
                return {"status": "error", "message": f"Bucket bulunamadı: {self.bucket_name}"}
            else:
                return {"status": "error", "message": f"S3 bağlantı hatası: {str(e)}"}
        except Exception as e:
            return {"status": "error", "message": f"Test hatası: {str(e)}"}
