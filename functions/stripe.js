const { onCall } = require("firebase-functions/v2/https");

exports.createStripePaymentIntent = onCall({
  secrets: ["STRIPE_SECRET_KEY"],
  timeoutSeconds: 30,
}, async (request) => {
  // Initialize stripe inside the function so the secret is loaded
  const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

  const { amount, currency = 'usd' } = request.data;

  if (!amount) {
    throw new Error("Missing amount");
  }

  try {
    // Determine the customer ID or email if you have users, but for a simple checkout:

    // Create a PaymentIntent with the order amount and currency
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Stripe expects cents
      currency: currency,
      // In the latest version of the API, specifying the automatic_payment_methods 
      // is optional because Stripe enables its functionality by default.
      automatic_payment_methods: {
        enabled: true,
      },
    });

    return {
      clientSecret: paymentIntent.client_secret,
    };
  } catch (error) {
    console.error("Stripe Error:", error);
    throw new Error(error.message);
  }
});
