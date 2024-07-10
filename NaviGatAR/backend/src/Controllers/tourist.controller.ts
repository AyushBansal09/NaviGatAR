import { Request, Response } from "express";
import { PrismaClient } from "@prisma/client";
import jwt from "jsonwebtoken";

const prisma = new PrismaClient();

export const register = async (req: Request, res: Response) => {
  const { firstName, lastName, email, password, mobileNum } = req.body;

  try {
    let errors: any = {};

    //validate
    const userData = await prisma.tourist.findFirst({
      where: {
        email,
        mobileNum,
      },
    });
    if (userData) errors.userData = "This user already exists!!";

    if (Object.keys(errors).length > 0) {
      return res.status(400).json(errors);
    }

    //create tourist
    const museumOwnerData = await prisma.tourist.create({
      data: {
        firstName,
        lastName,
        email,
        mobileNum,
        password,
      },
    });

    return res.json({registration: "success" });
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: "Internal Server Error" });
  }
};

export const login = async (req: Request, res: Response) => {
  const { email, password } = req.body;

  try {
    const userData = await prisma.tourist.findFirst({
      where: {
        email,
        password,
      },
      select: {
        id: true,
        token: true
      }
    });

    if (!userData)
      return res
        .status(404)
        .json({ username: "Worng username and password combination !!" });

    //gen JWT
    const token = jwt.sign({ email }, process.env.JWT_SECRET!);

    const updatedUserData = await prisma.tourist.update({
      where: {
        email
      },
      data: {
        token
      },
      select: {
        id: true,
        token: true
      }
    })

    return res.json({ userData: updatedUserData });
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: "Internal Server Error" });
  }
};

export const getAllMuseums = async (req: Request, res: Response) => {

  try {
    const museumData = await prisma.museum.findMany({
      select: {
        id: true,
        museumName: true,
        inTime: true,
        outTime: true,
        tags: true,
      },
    });
    console.log("Get all museums successful");
    return res.json({ data: museumData });
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: "Internal Server Error" });
  }
};

export const createComment = async (req: Request, res: Response) => {
  const { museumID, userID, commentBody, rating } = req.body;

  try {
    const commentData = await prisma.tourist.update({
      where: {
        id: userID,
      },
      data: {
        comments: {
          create: {
            museumID,
            commentBody,
            rating,
            datePosted: new Date(),
          },
        },
      }
    });

    // const commentData = await prisma.comments.create({
    //   data: {
    //     tourist: {
    //       create: {
    //         id: userID
    //       }
    //     },
    //     museumID,
    //     commentBody,
    //     rating,
    //     datePosted: new Date(),
    //   }
    // })

    return res.json(commentData);
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: "Internal Server Error" });
  }
};

export const getCommentFeed = async (req: Request, res: Response) => {
  const { museumID } = req.body;

  try {
    const commentsData = await prisma.comments.findMany({
      orderBy: {
        datePosted: "desc"
      },
      where: {
        museumID,
      },
      select: {
        id: true,
        museumID: true,
        commentBody: true,
        datePosted: true,
        rating: true,
        tourist: {
          select: {
            firstName: true,
            lastName: true
          }
        }
      }
    });

    return res.json({ comments: commentsData });
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: "Internal Server Error" });
  }
};

export const getMuseumDetails = async (req: Request, res: Response) => {
  const { museumID } = req.body;

  try {
    const museumData = await prisma.museum.findFirst({
      where: {
        id: museumID,
      },
      select: {
        id: true,
        museumName: true,
        inTime: true,
        outTime: true,
        aboutMuseum: true,
        tags: true
      }
    });

    return res.json({ museumDetails: museumData });
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: "Internal Server Error" });
  }
};