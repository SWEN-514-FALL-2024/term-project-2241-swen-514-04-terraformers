import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './UploadPage.css';

const UploadPage = () => {
  const navigate = useNavigate();
  const [selectedFile, setSelectedFile] = useState(null);
  const [selectedFilename, setSelectedFilename] = useState("");
  const [isFileUploaded, setIsFileUploaded] = useState(false);
  const [isAnalyzing, setIsAnalyzing] = useState(false);

  const generateUniqueFilename = (originalFilename) => {
    const extension = originalFilename.split('.').pop();
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(2, 8);
    return `${timestamp}_${randomStr}.${extension}`;
  };

  const handleFileChange = (event) => {
    const file = event.target.files[0];
    if (file && file.type === 'video/mp4') {
      const uniqueFilename = generateUniqueFilename(file.name);
      const uniqueFile = new File([file], uniqueFilename, {
        type: file.type,
        lastModified: file.lastModified,
      });
      
      setSelectedFile(uniqueFile);
      setSelectedFilename(file.name)
      setIsFileUploaded(true);
    } else {
      alert('Please upload an MP4 file.');
    }
  };

  const handleAnalyzeClick = async () => {
    if (!selectedFile) return;

    setIsAnalyzing(true);

    try {
      const postResponse = await fetch(`${import.meta.env.VITE_API_GATEWAY_URL}/url`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ key: selectedFile.name }),
      });

      const postResult = await postResponse.json();
      console.log(postResult)
      const uploadUrl = postResult.body.url;

      const putResponse = await fetch(uploadUrl, {
        method: 'PUT',
        headers: {
          'Content-Type': 'video/mp4',
        },
        body: selectedFile,
      });

      if (putResponse.ok) {
        // Get the filename without extension for the route
        const routeId = selectedFile.name.split('.')[0];
        navigate(`/${routeId}`);
      } else {
        alert('File upload failed.');
      }
    } catch (error) {
      console.error('Error uploading file:', error);
      alert('An error occurred during upload.');
    } finally {
      setIsAnalyzing(false);
    }
  };

  return (
    <div className="video-upload-container">
      <h1>Vidinsight</h1>
      <h2>Transcribe. Analyze. Synthesize.</h2>
      <div className="dropbox">
        <input
          type="file"
          accept="video/mp4"
          className="file-input"
          onChange={handleFileChange}
        />
        <span className={"dropbox-text" + (isFileUploaded ? " uploaded" : "")}>
          {isFileUploaded ? selectedFilename : 'Drop MP4 file here or click to upload'}
        </span>
      </div>

      <button
        onClick={handleAnalyzeClick}
        disabled={!isFileUploaded || isAnalyzing}
        className={`analyze-button ${!isFileUploaded || isAnalyzing ? 'disabled' : ''}`}
      >
        {isAnalyzing ? 'Uploading...' : 'Analyze'}
      </button>
    </div>
  );
};

export default UploadPage;