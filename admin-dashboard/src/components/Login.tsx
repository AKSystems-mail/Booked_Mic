import React, { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../firebase';

const Login: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (err: any) {
      console.error(err);
      setError(err.message || 'Failed to login');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container" style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div className="row w-100 justify-content-center">
        <div className="col-md-5 col-lg-4">
          <div className="text-center mb-4">
            <h1 style={{ color: '#64b5f6', fontWeight: 800, letterSpacing: '-1px' }}>BOOKED_MIC</h1>
            <p className="text-muted">Admin Dashboard</p>
          </div>
          <div className="card p-4">
            <div className="card-body">
              <h2 className="card-title text-center mb-4">Sign In</h2>
              {error && (
                <div className="alert alert-danger py-2" style={{ fontSize: '0.9rem' }}>
                  {error}
                </div>
              )}
              <form onSubmit={handleLogin}>
                <div className="mb-3">
                  <label className="form-label text-muted small text-uppercase fw-bold">Email</label>
                  <input
                    type="email"
                    className="form-control form-control-lg"
                    placeholder="admin@bookedmic.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                  />
                </div>
                <div className="mb-4">
                  <label className="form-label text-muted small text-uppercase fw-bold">Password</label>
                  <input
                    type="password"
                    className="form-control form-control-lg"
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                  />
                </div>
                <button type="submit" className="btn btn-primary btn-lg w-100 py-3" disabled={loading}>
                  {loading ? 'Signing in...' : 'Sign In'}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
