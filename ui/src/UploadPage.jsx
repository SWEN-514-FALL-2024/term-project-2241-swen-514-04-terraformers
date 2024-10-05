import React, { useState } from 'react';
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

const UploadPage = () => {
  const [selectedFile, setSelectedFile] = useState(null);
  const [fileContent, setFileContent] = useState("");

  // Configure the AWS S3 client
  const s3 = new S3Client({
    region: 'us-east-1',
    credentials: {
      accessKeyId: '',
      secretAccessKey: ''
    }
  });

  const handleFileInput = (e) => {
    const file = e.target.files[0];
    setSelectedFile(file);

    // Read the file content (assuming it's a text file)
    const reader = new FileReader();
    reader.onload = function (e) {
      setFileContent(e.target.result);
    };
    reader.readAsText(file);
  };

  const handleUpload = async () => {
    if (!selectedFile) {
      alert('Please select a file to upload.');
      return;
    }

    const params = {
      Bucket: '514project', // Replace with your S3 bucket name
      Key: selectedFile.name,        // File name will be the name of the uploaded file
      Body: fileContent,             // File content
      ContentType: 'text/plain'      // File MIME type
    };

    try {
      const data = await s3.send(new PutObjectCommand(params));
      console.log('File uploaded successfully:', data);
      alert('File uploaded successfully!');
    } catch (err) {
      console.error('Error uploading file:', err);
      alert('Error uploading file. Check the console for details.');
    }
  };

  return (
    <div>
      <h1>Upload a Text File</h1>
      <input type="file" accept=".txt" onChange={handleFileInput} />
      <button onClick={handleUpload}>Upload File</button>
    </div>
  );
};

export default UploadPage;
