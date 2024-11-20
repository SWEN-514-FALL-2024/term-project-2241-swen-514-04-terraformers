import React, { useEffect, useState, useCallback } from 'react';
import { useParams } from 'react-router-dom';
import './ResultPage.css';

const ResultPage = () => {
    const { id } = useParams();
    const [data, setData] = useState(null);
    const [error, setError] = useState(false);
    const [loading, setLoading] = useState(true);
    const [autoRefresh, setAutoRefresh] = useState(false);
    const [refreshInterval, setRefreshInterval] = useState(null);

    const fetchData = useCallback(async () => {
        try {
            const response = await fetch(`${import.meta.env.VITE_API_GATEWAY_URL}/results/${id}`);
            if (response.status === 500) {
                setError(true);
                return;
            }
            const result = await response.json();
            setData(result);
            setError(false);
        } catch (err) {
            setError(true);
        } finally {
            setLoading(false);
        }
    }, [id]);

    useEffect(() => {
        fetchData();
    }, [fetchData]);

    useEffect(() => {
        if (autoRefresh) {
            const interval = setInterval(fetchData, 10000);
            setRefreshInterval(interval);
        } else if (refreshInterval) {
            clearInterval(refreshInterval);
            setRefreshInterval(null);
        }
        return () => {
            if (refreshInterval) clearInterval(refreshInterval);
        };
    }, [autoRefresh, fetchData]);

    const ServiceCard = ({ title, content, isProcessing, noAnalysis }) => (
        <div className="service-card">
            <h2>{title}</h2>
            {isProcessing ? (
                <div className="processing-message">Still processing...</div>
            ) : noAnalysis ? (
                <div className="no-analysis-message">No analysis available for this video</div>
            ) : (
                content
            )}
        </div>
    );

    const RekognitionContent = ({ data }) => (
        <div className="rekognition-content">
            <div className="video-metadata">
                <h3>Video Metadata</h3>
                <p>Duration: {(data.videoMetadata.DurationMillis / 1000).toFixed(2)}s</p>
                <p>Resolution: {data.videoMetadata.FrameWidth}x{data.videoMetadata.FrameHeight}</p>
                <p>Frame Rate: {data.videoMetadata.FrameRate}fps</p>
            </div>
            <div className="labels-section">
                <h3>Detected Labels</h3>
                <div className="labels-timeline">
                    {data.labels.map((frame, index) => {
                        // Sort labels by confidence in descending order
                        const sortedLabels = [...frame.detectedLabels].sort((a, b) => b.confidence - a.confidence);
                        
                        return (
                            <div key={index} className="timeline-entry">
                                <div className="timestamp">{(frame.timestampSeconds).toFixed(2)}s</div>
                                <div className="labels-list">
                                    {sortedLabels.map((label, labelIndex) => (
                                        <div key={labelIndex} className="label-item">
                                            <span className="label-name">{label.name}</span>
                                            <span className="label-confidence">
                                                {label.confidence.toFixed(1)}%
                                            </span>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>
        </div>
    );

    const ComprehendContent = ({ data }) => (
        <div className="comprehend-content">
            <div className="sentiment-main">
                <h3>Overall Sentiment: {data.Sentiment}</h3>
            </div>
            <div className="sentiment-scores">
                {Object.entries(data.SentimentScore).map(([key, value]) => (
                    <div key={key} className="score-bar">
                        <div className="score-label">{key}</div>
                        <div className="score-container">
                            <div 
                                className="score-fill"
                                style={{ width: `${(value * 100)}%` }}
                            />
                            <span className="score-value">{(value * 100).toFixed(1)}%</span>
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );

    if (loading) {
        return (
            <div className="result-page">
                <div className="loading-spinner">Loading...</div>
            </div>
        );
    }

    if (error) {
        return (
            <div className="result-page">
                <div className="error-container">
                    <h2>Error</h2>
                    <p>Sorry, we couldn't process your video. Please try again.</p>
                    <button onClick={fetchData}>Retry</button>
                </div>
            </div>
        );
    }

    return (
        <div className="result-page">
            <div className="header">
                <h1>Analysis Results</h1>
                <div className="controls">
                    <button onClick={fetchData}>Refresh</button>
                    <label className="auto-refresh">
                        <input
                            type="checkbox"
                            checked={autoRefresh}
                            onChange={(e) => setAutoRefresh(e.target.checked)}
                        />
                        Auto-refresh
                    </label>
                </div>
            </div>
            
            <div className="services-grid">
                <ServiceCard
                    title="Video Analysis"
                    content={data.rekognition && <RekognitionContent data={data.rekognition} />}
                    isProcessing={!data.rekognition}
                />
                
                <ServiceCard
                    title="Sentiment Analysis"
                    content={data.comprehend?.exists && <ComprehendContent data={data.comprehend.data} />}
                    isProcessing={!data.comprehend}
                    noAnalysis={data.comprehend?.exists === false}
                />
                
                <ServiceCard
                    title="Transcription"
                    content={
                        data.transcribe?.exists && (
                            <div className="transcription-content">
                                {data.transcribe.data}
                            </div>
                        )
                    }
                    isProcessing={!data.transcribe}
                    noAnalysis={data.transcribe?.exists === false}
                />
            </div>
        </div>
    );
};

export default ResultPage;