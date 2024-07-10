import { Router } from "express";
import {
  createComment,
  getAllMuseums,
  getCommentFeed,
  getMuseumDetails,
  login,
  register,
} from "../Controllers/tourist.controller";
import { verifyTokenTourist } from "../Middleware/authTourist";

const router = Router();

router.post("/register", register);
router.post("/login", login);
router.get("/museumsFeed", getAllMuseums);
router.post("/createComment", createComment);
router.get("/commentFeed", getCommentFeed);
router.get("/museumDetail", getMuseumDetails);

export default router;
