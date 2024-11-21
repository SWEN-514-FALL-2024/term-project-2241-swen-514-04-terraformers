import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import UploadPage from './UploadPage.jsx'
import './index.css'
import Footer from './Footer.jsx'

createRoot(document.getElementById('root')).render(
  <div className="app-container">
    <UploadPage />
    <Footer />
  </div>
)
