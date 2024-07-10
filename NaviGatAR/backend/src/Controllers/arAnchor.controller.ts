import { Request, Response } from "express";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

export const uploadARAnchors = async (req: Request, res: Response) => {
  const { museumID, arAnchorList } = req.body;

  const ARData = JSON.stringify(arAnchorList)

  try {
    const anchorData = await prisma.museum.update({
      where: {
        id: museumID
      },
      data: {
        ARAnchorList: ARData,
      },
    });

    return res.json(anchorData)
  } catch (err) {
    console.log(err);
    res.status(500).json({ message: "Internal Server Error" });
  }
};


export const getARAnchors = async (req: Request, res: Response) => {

  const museumID = req.params.museumID

  try{
    const ARAnchorList = await prisma.museum.findFirst({
      where: {
        id: museumID
      },
      select: {
        ARAnchorList: true
      }
    });

    console.log(ARAnchorList)
    
    const ARData = JSON.parse(ARAnchorList!.ARAnchorList[0])

    return res.json(ARData)
  }catch (err) {
    console.log(err);
    res.status(500).json({ message: "Internal Server Error" });
  }
}
