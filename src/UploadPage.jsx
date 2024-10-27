// VideoUpload.jsx
import React, { useState } from 'react';
import './UploadPage.css'; // Import the CSS file

const UploadPage = () => {
  const [selectedFile, setSelectedFile] = useState(null);
  const [isFileUploaded, setIsFileUploaded] = useState(false);
  const [isAnalyzing, setIsAnalyzing] = useState(false);

  // Handle file drop or file selection
  const handleFileChange = (event) => {
    const file = event.target.files[0];
    if (file && file.type === 'video/mp4') {
      setSelectedFile(file);
      setIsFileUploaded(true);
    } else {
      alert('Please upload an MP4 file.');
    }
  };

  // Handle the "Analyze" button click
  const handleAnalyzeClick = async () => {
    if (!selectedFile) return;

    setIsAnalyzing(true);

    try {
      console.log(import.meta.env);
      // 1. Make POST request to get upload URL
      const postResponse = await fetch(import.meta.env.API_GATEWAY_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ key: selectedFile.name }),
      });

      const postResult = await postResponse.json();
      const uploadUrl = postResult.url;

      // 2. Make PUT request to upload the file to the obtained URL
      const putResponse = await fetch(uploadUrl, {
        method: 'PUT',
        headers: {
          'Content-Type': 'video/mp4',
        },
        body: selectedFile, // The video file itself
      });

      if (putResponse.ok) {
        alert('File uploaded successfully!');
      } else {
        alert('File upload failed.');
      }
    } catch (error) {
      console.error('Error uploading file:', error);
      alert('Error during analysis or upload.');
    } finally {
      setIsAnalyzing(false);
    }
  };

  return (
    <div className="video-upload-container">
      <h1>Vidinsight</h1>
      <h2>Transcribe. Analyze. Synthesize.</h2>
      {/* Square drop box */}
      <div className="dropbox">
        <input
          type="file"
          accept="video/mp4"
          className="file-input"
          onChange={handleFileChange}
        />
        <span className={"dropbox-text" + (isFileUploaded ? " uploaded" : "")}>
          {isFileUploaded ? selectedFile.name : 'Drop MP4 file here or click to upload'}
        </span>
      </div>

      {/* Analyze button */}
      <button
        onClick={handleAnalyzeClick}
        disabled={!isFileUploaded || isAnalyzing}
        className={`analyze-button ${!isFileUploaded || isAnalyzing ? 'disabled' : ''}`}
      >
        {isAnalyzing ? 'Analyzing...' : 'Analyze'}
      </button>
    </div>
  );
};

export default UploadPage;
