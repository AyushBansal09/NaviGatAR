import express from "express";
import dotenv from "dotenv";
import morgan from "morgan";

import pathRoutes from "../src/Routes/path"
import museumOwnerRoutes from "../src/Routes/museumOwner"
import touristRoutes from "../src/Routes/tourist"

dotenv.config();

const app = express();
const PORT = process.env.PORT;

app.use(morgan("dev"));
app.use(express.json());
app.use("/api/path", pathRoutes)
app.use("/api/museumOwner", museumOwnerRoutes)
app.use("/api/tourist", touristRoutes)



app.get("/", (_, res) => res.send("Hello World! \n"));
app.listen(PORT, async () => {
  try {
    console.log(`Server running at PORT:${PORT} 🚀`);
    console.log("Database Connected !!");
  } catch (err) {
    console.log(err);
  }
});
