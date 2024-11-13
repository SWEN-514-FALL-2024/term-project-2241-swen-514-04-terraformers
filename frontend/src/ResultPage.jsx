import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';

const ResultPage = () => {
    const { id } = useParams();
    const [data, setData] = useState(null);
    const [error, setError] = useState(false);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchData = async () => {
            console.log(id)
            try {
                console.log(`${import.meta.env.VITE_API_GATEWAY_URL}/results/${id}`, {
                    method: 'GET'
                })
                const response = await fetch(`${import.meta.env.VITE_API_GATEWAY_URL}/results/${id}`);

                if (response.status === 500) {
                    setError(true);
                    return;
                }

                const result = await response.json();
                setData(result);
            } catch (err) {
                setError(true);
            } finally {
                setLoading(false);
            }
        };

        fetchData();
    }, [id]);

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
                </div>
            </div>
        );
    }

    return (
        <div className="result-page">
            <h1>Analysis Results</h1>
            <pre className="results-data">
                {JSON.stringify(data, null, 2)}
            </pre>
        </div>
    );
};

export default ResultPage;