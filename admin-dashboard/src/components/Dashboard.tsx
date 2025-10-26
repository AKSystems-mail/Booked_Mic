
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
  stageName?: string;
}

const Dashboard: React.FC = () => {
  const [shows, setShows] = useState<Show[]>([]);
  const [loading, setLoading] = useState(true);
  
    useEffect(() => {
      const fetchShowsAndPerformers = async () => {
        try {
          const querySnapshot = await getDocs(collection(db, 'Lists'));
          const showsData = await Promise.all(querySnapshot.docs.map(async (document) => {
            const data = document.data();
            let stageName = 'Unknown';
            if (data.userId) {
              const userDocRef = doc(db, 'users', data.userId);
              const userDoc = await getDoc(userDocRef);
              if (userDoc.exists()) {
                stageName = (userDoc.data() as { stageName: string }).stageName || 'Unknown';
              }
            }
            return {
              id: document.id,
              showName: data.listName,
              date: data.date,
              address: data.address,
              numberOfSpots: data.numberOfSpots,
              userId: data.userId,
              stageName: stageName,
            };
          }));
          setShows(showsData);
  
        } catch (error) {
          console.error("Error fetching shows: ", error);
        }
        setLoading(false);
      };
  
      fetchShowsAndPerformers();
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
  
    const handleLogout = () => {
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
              <th>Stage Name</th>
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
                <td>{show.stageName}</td>
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
