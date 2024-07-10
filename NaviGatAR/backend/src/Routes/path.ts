import { Router } from 'express'
import { getARAnchors, uploadARAnchors } from '../Controllers/arAnchor.controller';

const router = Router();

router.post("/uploadPath", uploadARAnchors)
router.get("/getPath/:museumID", getARAnchors)

export default router