import React from "react";
import { useDispatch, useSelector } from "react-redux";
import { removeItem, updateQuantity } from "./redux/CartSlice";

const CartItem = () => {
const dispatch = useDispatch();
const items = useSelector((state) => state.cart.items);

const totalItems = items.reduce(
(total, item) => total + item.quantity,
0
);

const totalPrice = items.reduce(
(total, item) => total + item.price * item.quantity,
0
);

if (items.length === 0) {
return ( <section className="cart" id="cart"> <h2>Shopping Cart</h2> <p>Your cart is empty.</p> </section>
);
}

return ( <section className="cart" id="cart"> <h2>Shopping Cart</h2>


  <p>Total Items: {totalItems}</p>

  {items.map((item) => (
    <article className="cart-item" key={item.id}>
      <img src={item.image} alt={item.name} />

      <div className="cart-item-info">
        <h3>{item.name}</h3>
        <p>${item.price.toFixed(2)} each</p>
        <p>
          Subtotal: ${(item.price * item.quantity).toFixed(2)}
        </p>
      </div>

      <div className="quantity-controls">
        <button
          onClick={() =>
            dispatch(
              updateQuantity({
                id: item.id,
                quantity: item.quantity - 1,
              })
            )
          }
        >
          -
        </button>

        <span>{item.quantity}</span>

        <button
          onClick={() =>
            dispatch(
              updateQuantity({
                id: item.id,
                quantity: item.quantity + 1,
              })
            )
          }
        >
          +
        </button>
      </div>

      <button
        className="remove-btn"
        onClick={() => dispatch(removeItem(item.id))}
      >
        Remove
      </button>
    </article>
  ))}

  <h3>Total: ${totalPrice.toFixed(2)}</h3>
</section>


);
};

export default CartItem;
