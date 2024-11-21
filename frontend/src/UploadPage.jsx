import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Upload, FileVideo } from 'lucide-react';
import './UploadPage.css';

const UploadPage = () => {
  const navigate = useNavigate();
  const [selectedFile, setSelectedFile] = useState(null);
  const [selectedFilename, setSelectedFilename] = useState("");
  const [isFileUploaded, setIsFileUploaded] = useState(false);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [dragActive, setDragActive] = useState(false);

  const generateUniqueFilename = (originalFilename) => {
    const extension = originalFilename.split('.').pop();
    const timestamp = Date.now();
    const randomStr = Math.random().toString(36).substring(2, 8);
    return `${timestamp}_${randomStr}.${extension}`;
  };

  const handleFileChange = (event) => {
    const file = event.target.files[0];
    handleFile(file);
  };

  const handleFile = (file) => {
    if (file && file.type === 'video/mp4') {
      const uniqueFilename = generateUniqueFilename(file.name);
      const uniqueFile = new File([file], uniqueFilename, {
        type: file.type,
        lastModified: file.lastModified,
      });
      
      setSelectedFile(uniqueFile);
      setSelectedFilename(file.name);
      setIsFileUploaded(true);
    } else {
      alert('Please upload an MP4 file.');
    }
  };

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true);
    } else if (e.type === "dragleave") {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFile(e.dataTransfer.files[0]);
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
        body: JSON.stringify({ key: selectedFile.name, name: selectedFilename }),
      });

      const postResult = await postResponse.json();
      const uploadUrl = postResult.body.url;

      const putResponse = await fetch(uploadUrl, {
        method: 'PUT',
        headers: {
          'Content-Type': 'video/mp4',
        },
        body: selectedFile,
      });

      if (putResponse.ok) {
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
    <div className="upload-page">
      <div className="upload-container">
        <div className="header">
          <h1>Vidinsight</h1>
          <h2>Transcribe. Analyze. Synthesize.</h2>
        </div>

        <div 
          className={`dropbox ${dragActive ? 'drag-active' : ''} ${isFileUploaded ? 'has-file' : ''}`}
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
        >
          <input
            type="file"
            accept="video/mp4"
            className="file-input"
            onChange={handleFileChange}
          />
          {isFileUploaded ? (
            <div className="file-info">
              <FileVideo size={48} />
              <span className="filename">{selectedFilename}</span>
            </div>
          ) : (
            <div className="upload-prompt">
              <Upload size={48} />
              <span>Drop MP4 file here or click to upload</span>
            </div>
          )}
        </div>

        <button
          onClick={handleAnalyzeClick}
          disabled={!isFileUploaded || isAnalyzing}
          className="analyze-button"
        >
          {isAnalyzing ? 'Uploading...' : 'Analyze Video'}
        </button>
      </div>
    </div>
  );
};

export default UploadPage;