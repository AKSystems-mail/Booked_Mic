import React, { useState, useEffect, useMemo } from 'react';
import { collection, getDocs, deleteDoc, doc, getDoc, query, orderBy } from 'firebase/firestore';
import { db } from '../firebase';
import { signOut, onAuthStateChanged, User } from 'firebase/auth';
import { auth } from '../firebase';

interface Show {
  id: string;
  showName: string;
  date: any; 
  address: string;
  numberOfSpots: number;
  userId: string;
  stageName?: string;
}

type SortConfig = {
  key: keyof Show | null;
  direction: 'ascending' | 'descending';
};

const Dashboard: React.FC = () => {
  const [shows, setShows] = useState<Show[]>([]);
  const [loading, setLoading] = useState(true);
  const [adminStatus, setAdminStatus] = useState<string>('Initializing...');
  const [sortConfig, setSortConfig] = useState<SortConfig>({ key: 'date', direction: 'descending' });
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user: User | null) => {
      if (user) {
        setAdminStatus('Verifying Permissions...');
        await fetchAdminData(user);
      } else {
        setAdminStatus('Not Logged In');
        setLoading(false);
      }
    });

    return () => unsubscribe();
  }, []);

  const fetchAdminData = async (user: User) => {
    try {
      // 1. Check Admin Privilege
      const adminDocRef = doc(db, 'admins', user.uid);
      const adminDoc = await getDoc(adminDocRef);
      const isAuthorized = adminDoc.exists();
      setAdminStatus(isAuthorized ? 'Authorized Admin' : 'Unauthorized User');

      if (!isAuthorized) {
        setErrorMessage("You do not have administrative privileges to view this data.");
        setLoading(false);
        return;
      }

      // 2. Fetch Lists
      const querySnapshot = await getDocs(collection(db, 'Lists'));
      const showsData = await Promise.all(querySnapshot.docs.map(async (document) => {
        const data = document.data();
        let stageName = 'Unknown';
        if (data.userId) {
          try {
            const userDocRef = doc(db, 'users', data.userId);
            const userDoc = await getDoc(userDocRef);
            if (userDoc.exists()) {
              stageName = (userDoc.data() as { stageName: string }).stageName || 'Unknown';
            }
          } catch (e) {
            console.warn(`Could not fetch stageName for user ${data.userId}`);
          }
        }
        return {
          id: document.id,
          showName: data.listName || 'Unnamed List',
          date: data.date,
          address: data.address || 'No Address',
          numberOfSpots: (data.numberOfSpots || 0) + (data.numberOfWaitlistSpots || 0) + (data.numberOfBucketSpots || 0),
          userId: data.userId,
          stageName: stageName,
        };
      }));
      setShows(showsData);
      setErrorMessage(null);
    } catch (error: any) {
      console.error("Error fetching data: ", error);
      setErrorMessage(`Error: ${error.message || 'Failed to load data'}`);
    } finally {
      setLoading(false);
    }
  };

  const sortedShows = useMemo(() => {
    let sortableItems = [...shows];
    if (sortConfig.key !== null) {
      sortableItems.sort((a, b) => {
        let aValue: any = a[sortConfig.key!];
        let bValue: any = b[sortConfig.key!];

        if (sortConfig.key === 'date') {
          aValue = aValue?.seconds || 0;
          bValue = bValue?.seconds || 0;
        } else {
          aValue = (aValue || '').toString().toLowerCase();
          bValue = (bValue || '').toString().toLowerCase();
        }

        if (aValue < bValue) return sortConfig.direction === 'ascending' ? -1 : 1;
        if (aValue > bValue) return sortConfig.direction === 'ascending' ? 1 : -1;
        return 0;
      });
    }
    return sortableItems;
  }, [shows, sortConfig]);

  const requestSort = (key: keyof Show) => {
    let direction: 'ascending' | 'descending' = 'ascending';
    if (sortConfig.key === key && sortConfig.direction === 'ascending') {
      direction = 'descending';
    }
    setSortConfig({ key, direction });
  };

  const getSortIcon = (key: keyof Show) => {
    if (sortConfig.key !== key) return <span className="ms-1 text-muted opacity-25">↕</span>;
    return sortConfig.direction === 'ascending' ? <span className="ms-1 text-primary">↑</span> : <span className="ms-1 text-primary">↓</span>;
  };

  const handleDelete = async (id: string) => {
    if (window.confirm('Are you sure you want to delete this show?')) {
      try {
        await deleteDoc(doc(db, 'Lists', id));
        setShows(shows.filter(show => show.id !== id));
        alert('Show deleted.');
      } catch (error: any) {
        alert(`Delete failed: ${error.message}`);
      }
    }
  };

  const handleLogout = () => signOut(auth);

  if (loading) {
    return (
      <div className="d-flex flex-column justify-content-center align-items-center" style={{ minHeight: '100vh', backgroundColor: '#212121', color: 'white' }}>
        <div className="spinner-border text-primary mb-3" role="status"></div>
        <div>{adminStatus}</div>
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', paddingBottom: '50px', backgroundColor: '#212121', color: '#e0e0e0' }}>
      <nav className="navbar navbar-dark bg-dark mb-5 py-3 shadow-sm" style={{ borderBottom: '1px solid #333' }}>
        <div className="container">
          <span className="navbar-brand mb-0 h1 fw-bold" style={{ color: '#64b5f6' }}>BOOKED_MIC <span className="text-muted fw-normal small ms-2">ADMIN</span></span>
          <div className="d-flex align-items-center">
            <span className={`badge me-3 ${adminStatus === 'Authorized Admin' ? 'bg-success' : 'bg-danger'}`}>
              {adminStatus}
            </span>
            <button className="btn btn-outline-light btn-sm" onClick={handleLogout}>Sign Out</button>
          </div>
        </div>
      </nav>

      <div className="container">
        {errorMessage && (
          <div className="alert alert-danger mb-4 shadow-sm">
            {errorMessage}
          </div>
        )}

        <div className="d-flex justify-content-between align-items-end mb-4">
          <div>
            <h2 className="fw-bold mb-0">Active Shows</h2>
            <p className="text-muted small mb-0">Manage all performance lists across the platform</p>
          </div>
          <div className="text-end">
            <span className="badge bg-primary text-dark rounded-pill px-3 py-2">{shows.length} Total Shows</span>
          </div>
        </div>
        
        <div className="card border-0 shadow-lg bg-dark text-white" style={{ overflow: 'hidden' }}>
          <div className="table-responsive">
            <table className="table table-dark table-hover mb-0">
              <thead>
                <tr className="border-bottom border-secondary">
                  <th className="ps-4 py-3 cursor-pointer" onClick={() => requestSort('showName')} style={{ cursor: 'pointer' }}>
                    Show Name {getSortIcon('showName')}
                  </th>
                  <th className="py-3 cursor-pointer" onClick={() => requestSort('stageName')} style={{ cursor: 'pointer' }}>
                    Host {getSortIcon('stageName')}
                  </th>
                  <th className="py-3 cursor-pointer" onClick={() => requestSort('date')} style={{ cursor: 'pointer' }}>
                    Date {getSortIcon('date')}
                  </th>
                  <th className="py-3">Address</th>
                  <th className="py-3 text-center">Spots</th>
                  <th className="py-3 text-end pe-4">Actions</th>
                </tr>
              </thead>
              <tbody>
                {sortedShows.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center py-5 text-muted italic">
                      {errorMessage ? 'Failed to load shows.' : 'No active shows found.'}
                    </td>
                  </tr>
                ) : (
                  sortedShows.map(show => (
                    <tr key={show.id} className="align-middle border-bottom border-secondary">
                      <td className="ps-4 fw-bold">{show.showName}</td>
                      <td>{show.stageName}</td>
                      <td>{show.date?.toDate ? show.date.toDate().toLocaleDateString() : 'N/A'}</td>
                      <td className="small text-white">{show.address}</td>
                      <td className="text-center">
                        <span className="badge bg-secondary">{show.numberOfSpots}</span>
                      </td>
                      <td className="text-end pe-4">
                        <button className="btn btn-sm btn-outline-danger border-0" onClick={() => handleDelete(show.id)}>
                          Delete
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
