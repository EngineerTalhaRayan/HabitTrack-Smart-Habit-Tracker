import React, { useState } from "react";
import "./App.css";
import AboutUs from "./components/AboutUs";
import ProductList from "./components/ProductList";
import CartItem from "./components/CartItem";

const App = () => {
const [showStore, setShowStore] = useState(false);

return ( <div className="app">
{!showStore ? ( <main className="landing-page"> <div className="landing-content"> <h1>Paradise Nursery</h1>


        <p>
          Bring nature into your home with beautiful, healthy, and
          carefully selected plants.
        </p>

        <button
          className="get-started-btn"
          onClick={() => setShowStore(true)}
        >
          Get Started
        </button>
      </div>
    </main>
  ) : (
    <>
      <AboutUs />
      <ProductList />
      <CartItem />
    </>
  )}
</div>


);
};

export default App;
