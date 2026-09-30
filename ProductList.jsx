import React from "react";
import { useDispatch } from "react-redux";
import { addItem } from "./redux/CartSlice";

const products = [
{
id: 1,
name: "Snake Plant",
price: 25,
category: "Indoor Plants",
image:
"https://images.unsplash.com/photo-1593691509543-c55fb32e5cee?auto=format&fit=crop&w=600&q=80",
},
{
id: 2,
name: "Monstera",
price: 35,
category: "Indoor Plants",
image:
"https://images.unsplash.com/photo-1614594575271-0d5a1f4a3f0e?auto=format&fit=crop&w=600&q=80",
},
{
id: 3,
name: "Peace Lily",
price: 30,
category: "Flowering Plants",
image:
"https://images.unsplash.com/photo-1593691509543-c55fb32e5cee?auto=format&fit=crop&w=600&q=80",
},
{
id: 4,
name: "Aloe Vera",
price: 20,
category: "Succulents",
image:
"https://images.unsplash.com/photo-1509423350716-97f9360b4e09?auto=format&fit=crop&w=600&q=80",
},
{
id: 5,
name: "Rubber Plant",
price: 40,
category: "Indoor Plants",
image:
"https://images.unsplash.com/photo-1604762524889-3e2fcc145683?auto=format&fit=crop&w=600&q=80",
},
{
id: 6,
name: "ZZ Plant",
price: 32,
category: "Indoor Plants",
image:
"https://images.unsplash.com/photo-1632207691143-643e2f7e6d32?auto=format&fit=crop&w=600&q=80",
},
];

const ProductList = () => {
const dispatch = useDispatch();

return ( <section className="product-list" id="products"> <h2>Our Plants</h2>


  <div className="products-grid">
    {products.map((product) => (
      <article className="product-card" key={product.id}>
        <img src={product.image} alt={product.name} />

        <h3>{product.name}</h3>

        <p>{product.category}</p>

        <p>${product.price.toFixed(2)}</p>

        <button onClick={() => dispatch(addItem(product))}>
          Add to Cart
        </button>
      </article>
    ))}
  </div>
</section>


);
};

export default ProductList;
