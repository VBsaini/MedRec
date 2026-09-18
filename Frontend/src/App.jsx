import React, { useState, useEffect } from 'react'
import { BrowserRouter, Routes, Route, useParams, useNavigate } from 'react-router-dom'

const API_BASE = '/api'

// ============ COMPONENTS ============

function Navbar() {
  return (
    <nav className="navbar">
      <div className="nav-brand">
        <span className="logo">📋</span>
        <h1>MedRec</h1>
      </div>
      <div className="nav-links">
        <a href="/">Home</a>
        <a href="/admin">Admin</a>
      </div>
    </nav>
  )
}

function Home() {
  return (
    <div className="page home-page">
      <div className="hero">
        <div className="hero-icon">💳</div>
        <h2>Tap Your Card to Access Medical Records</h2>
        <p className="subtitle">
          Place your RFID card on the reader to instantly view your complete medical history.
        </p>
      </div>
      
      <div className="info-grid">
        <div className="info-card">
          <span className="icon">🔒</span>
          <h3>Secure</h3>
          <p>Your records are protected and only accessible via your unique RFID card.</p>
        </div>
        <div className="info-card">
          <span className="icon">⚡</span>
          <h3>Instant Access</h3>
          <p>No login required — tap your card and view your records immediately.</p>
        </div>
        <div className="info-card">
          <span className="icon">🏥</span>
          <h3>Complete History</h3>
          <p>Allergies, medications, surgeries, and emergency contacts in one place.</p>
        </div>
      </div>
    </div>
  )
}

function RecordView() {
  const { cardId } = useParams()
  const navigate = useNavigate()
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    fetchRecord()
  }, [cardId])

  const fetchRecord = async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetch(`${API_BASE}/records/user/card/${cardId}`)
      if (res.status === 404) {
        setError('Card not registered in the system.')
        setLoading(false)
        return
      }
      if (!res.ok) throw new Error('Server error')
      const data = await res.json()
      setUser(data)
    } catch (err) {
      setError('Failed to fetch record. Is the backend running?')
    }
    setLoading(false)
  }

  if (loading) return <div className="page loading"><div className="spinner"></div><p>Loading record...</p></div>
  
  if (error) return (
    <div className="page error-page">
      <div className="error-icon">❌</div>
      <h2>Access Denied</h2>
      <p>{error}</p>
      <p className="card-id-display">Card ID: <code>{cardId}</code></p>
      <button onClick={() => navigate('/')} className="btn btn-primary">Back to Home</button>
    </div>
  )

  if (!user) return null

  return (
    <div className="page record-page">
      <div className="record-header">
        <div className="patient-info">
          <div className="avatar">{user.name?.charAt(0) || '?'}</div>
          <div>
            <h2>{user.name || 'Unknown Patient'}</h2>
            <p className="card-id">Card: {user.card_Id}</p>
          </div>
        </div>
        <div className="patient-meta">
          {user.blood_group && <span className="badge badge-blood">{user.blood_group}</span>}
          {user.age && <span className="badge">{user.age} yrs</span>}
          {user.gender && <span className="badge">{user.gender}</span>}
        </div>
      </div>

      {/* Critical Alerts */}
      {(user.allergies?.length > 0 || user.heart?.status || user.diabetic?.status) && (
        <section className="section alerts-section">
          <h3>⚠️ Critical Alerts</h3>
          <div className="alert-grid">
            {user.allergies?.map((a, i) => (
              <div key={i} className="alert-card allergy">
                <strong>{a.allergens}</strong>
                <span>{a.reactions} — {a.severity}</span>
              </div>
            ))}
            {user.heart?.status && (
              <div className="alert-card heart">
                <strong>Heart Condition</strong>
                <span>{user.heart.details || 'Under treatment'}</span>
                {user.heart.since && <small>Since: {new Date(user.heart.since).toLocaleDateString()}</small>}
              </div>
            )}
            {user.diabetic?.status && (
              <div className="alert-card diabetic">
                <strong>Diabetes</strong>
                <span>{user.diabetic.type || 'Type not specified'}</span>
                {user.diabetic.since && <small>Since: {new Date(user.diabetic.since).toLocaleDateString()}</small>}
              </div>
            )}
          </div>
        </section>
      )}

      {/* Medications */}
      {(user.heart?.medications?.length > 0 || user.mental_health?.medications?.length > 0) && (
        <section className="section">
          <h3>💊 Current Medications</h3>
          <div className="medication-list">
            {[...(user.heart?.medications || []), ...(user.mental_health?.medications || [])]
              .filter((v, i, a) => a.findIndex(m => m._id === v._id) === i)
              .map((med, i) => (
                <div key={i} className="med-card">
                  <strong>{med.name}</strong>
                  <span>{med.dosage} — {med.frequency}</span>
                  <small>Prescribed by: {med.prescribedBy || 'Unknown'}</small>
                </div>
              ))
            }
          </div>
        </section>
      )}

      {/* Medical History */}
      {user.medical_history?.length > 0 && (
        <section className="section">
          <h3>📝 Medical History</h3>
          <div className="history-list">
            {user.medical_history.map((h, i) => (
              <div key={i} className="history-item">
                <p>{h.past_illnesses || h.details || 'Details not available'}</p>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Surgeries */}
      {user.heart?.surgeries?.length > 0 && (
        <section className="section">
          <h3>🏥 Surgeries</h3>
          <div className="surgery-list">
            {user.heart.surgeries.map((s, i) => (
              <div key={i} className="surgery-card">
                <strong>{s.surgeryType}</strong>
                <span>{s.hospitalName} — Dr. {s.doctorName}</span>
                <small>{new Date(s.surgeryDate).toLocaleDateString()}</small>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Family History */}
      {user.family_history?.length > 0 && (
        <section className="section">
          <h3>👨‍👩‍👧 Family History</h3>
          <div className="family-list">
            {user.family_history.map((f, i) => (
              <div key={i} className="family-item">
                <strong>{f.relationship}</strong>
                <span>{f.conditions}</span>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Mental Health */}
      {user.mental_health?.status && (
        <section className="section">
          <h3>🧠 Mental Health</h3>
          <div className="mental-health-card">
            <p>{user.mental_health.details || 'Under treatment'}</p>
            {user.mental_health.since && <small>Since: {new Date(user.mental_health.since).toLocaleDateString()}</small>}
          </div>
        </section>
      )}

      {/* Emergency Contacts */}
      {user.emergency_contact?.length > 0 && (
        <section className="section emergency-section">
          <h3>🚨 Emergency Contacts</h3>
          <div className="emergency-grid">
            {user.emergency_contact.map((ec, i) => (
              <div key={i} className="emergency-card">
                <strong>{ec.name}</strong>
                <span>{ec.relationship}</span>
                <a href={`tel:${ec.phone_number}`} className="phone-link">{ec.phone_number}</a>
              </div>
            ))}
          </div>
        </section>
      )}

      <div className="record-footer">
        <p>Record accessed: {new Date().toLocaleString()}</p>
        <button onClick={() => window.print()} className="btn btn-outline">🖨️ Print Record</button>
      </div>
    </div>
  )
}

function Admin() {
  const [cardId, setCardId] = useState('')
  const navigate = useNavigate()

  const handleLookup = (e) => {
    e.preventDefault()
    if (cardId.trim()) navigate(`/record/${cardId.trim()}`)
  }

  return (
    <div className="page admin-page">
      <h2>Manual Card Lookup</h2>
      <form onSubmit={handleLookup} className="lookup-form">
        <input
          type="text"
          placeholder="Enter Card UID..."
          value={cardId}
          onChange={e => setCardId(e.target.value)}
          className="lookup-input"
        />
        <button type="submit" className="btn btn-primary">View Record</button>
      </form>
      <p className="help-text">Use this page if you need to manually look up a card without the RFID reader.</p>
    </div>
  )
}

function App() {
  return (
    <BrowserRouter>
      <div className="app">
        <Navbar />
        <main className="main-content">
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/record/:cardId" element={<RecordView />} />
            <Route path="/admin" element={<Admin />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  )
}

export default App
