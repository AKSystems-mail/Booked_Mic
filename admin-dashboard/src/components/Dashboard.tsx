
import React, { useState, useEffect } from 'react';
import { collection, getDocs, deleteDoc, doc, getDoc } from 'firebase/firestore';
import { db } from '../firebase';
import { signOut } from 'firebase/auth';
import { auth } from '../firebase';

// This is the structure of your 'Show' object from the Flutter app.
// We define it here to use it with TypeScript.
interface Show {
  id: string;
  showName: string;
  date: any; 
  address: string;
  numberOfSpots: number;
  userId: string;
}

const Dashboard: React.FC = () => {
  const [shows, setShows] = useState<Show[]>([]);
  const [loading, setLoading] = useState(true);
    const [performerNames, setPerformerNames] = useState<{[key: string]: string}>({});
  
    useEffect(() => {
      const fetchShows = async () => {
        try {
          const querySnapshot = await getDocs(collection(db, 'Lists'));
          const showsData = querySnapshot.docs.map(doc => {
            const data = doc.data();
            return {
              id: doc.id,
              showName: data.listName,
              date: data.date,
              address: data.address,
              numberOfSpots: data.numberOfSpots,
              userId: data.userId
            };
          });
          setShows(showsData);
  
          const userIds = showsData.map(show => show.userId).filter(id => id);
          const uniqueUserIds = [...new Set(userIds)];
  
          const names: {[key: string]: string} = {};
          for (const userId of uniqueUserIds) {
            if (userId) {
              const userDoc = await getDoc(doc(db, 'users', userId));
              if (userDoc.exists()) {
                names[userId] = userDoc.data().performerName || 'Unknown';
              }
            }
          }
          setPerformerNames(names);
  
        } catch (error) {
          console.error("Error fetching shows: ", error);
        }
        setLoading(false);
      };
  
      fetchShows();
    }, []);
  
    const handleDelete = async (id: string) => {
      if (window.confirm('Are you sure you want to delete this show?')) {
        try {
          await deleteDoc(doc(db, 'Lists', id));
          setShows(shows.filter(show => show.id !== id));
        } catch (error) {
          console.error("Error deleting show: ", error);
        }
      }
    };
  
    const handleLogout = (). => {
      signOut(auth);
    };
  
    if (loading) {
      return <div>Loading...</div>;
    }
  
    return (
      <div className="container mt-5">
        <div className="d-flex justify-content-between align-items-center mb-3">
          <h1>Dashboard</h1>
          <button className="btn btn-danger" onClick={handleLogout}>Logout</button>
        </div>
        
  
  
        <table className="table table-striped">
          <thead>
            <tr>
              <th>Show Name</th>
              <th>Created By</th>
              <th>Date</th>
              <th>Address</th>
              <th>Spots</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {shows.map(show => (
              <tr key={show.id}>
                <td>{show.showName}</td>
                <td>{performerNames[show.userId]}</td>
                <td>{show.date.toDate().toLocaleDateString()}</td>
                <td>{show.address}</td>
                <td>{show.numberOfSpots}</td>              <td>
                <button className="btn btn-sm btn-secondary me-2">Edit</button>
                <button 
                  className="btn btn-sm btn-danger"
                  onClick={() => handleDelete(show.id)}
                >
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default Dashboard;
