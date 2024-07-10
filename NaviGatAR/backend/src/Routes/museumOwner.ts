import { Router } from 'express'
import { addMuseumDetails, login, register } from "../Controllers/museumOwner.controller"
import { verifyTokenMuseumOwner } from '../Middleware/authMuseumOwner';

const router = Router();

router.post("/register", register)
router.post("/login", login)
router.post("/addMuseumDetails", addMuseumDetails)


export default router