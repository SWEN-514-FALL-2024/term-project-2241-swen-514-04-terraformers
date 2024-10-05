import React, { useState } from 'react';
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const UploadPage = () => {
  const [selectedFile, setSelectedFile] = useState(null);

  const s3 = new S3Client({
    region: 'YOUR_BUCKET_REGION',
    credentials: {
      accessKeyId: 'YOUR_ACCESS_KEY_ID',
      secretAccessKey: 'YOUR_SECRET_ACCESS_KEY'
    }
  });

  const handleFileInput = (e) => {
    setSelectedFile(e.target.files[0]);
  };

  const handleUpload = async () => {
    if (!selectedFile) {
      alert('Please select a file!');
      return;
    }

    const params = {
      Bucket: 'my-video-uploads',
      Key: selectedFile.name,
      Body: selectedFile,
      ContentType: selectedFile.type
    };

    try {
      const data = await s3.send(new PutObjectCommand(params));
      console.log('Upload successful:', data);
      alert('File uploaded successfully!');
    } catch (err) {
      console.error('There was an error uploading your file: ', err.message);
    }
  };

  return (
    <div>
      <h1>Upload an MP4 File</h1>
      <input type="file" onChange={handleFileInput} />
      <button onClick={handleUpload}>Upload</button>
    </div>
  );
};

export default UploadPage;
