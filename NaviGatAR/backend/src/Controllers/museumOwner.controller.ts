import { Request, Response } from "express";
import { PrismaClient } from "@prisma/client";
import jwt from "jsonwebtoken";

const prisma = new PrismaClient();

export const register = async (req: Request, res: Response) => {
  const { firstName, lastName, email, password, mobileNum } = req.body;

  try {
    let errors: any = {};

    //validate
    const userData = await prisma.museumOwner.findFirst({
      where: {
        email,
        mobileNum,
      },
    });
    if (userData) errors.userData = "This user already exists!!";

    if (Object.keys(errors).length > 0) {
      return res.status(400).json(errors);
    }

    //create museum owner
    const museumOwnerData = await prisma.museumOwner.create({
      data: {
        firstName,
        lastName,
        email,
        mobileNum,
        password,
      },
    });

    return res.json(museumOwnerData);
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: "Internal Server Error" });
  }
};

export const login = async (req: Request, res: Response) => {
  const { email, password } = req.body;

  try {
    const userData = await prisma.museumOwner.findFirst({
      where: {
        email,
        password,
      },
    });

    if (!userData)
      return res
        .status(404)
        .json({ username: "Worng username and password combination !!" });

    //gen JWT
    const token = jwt.sign({ email }, process.env.JWT_SECRET!);

    const updatedUserData = await prisma.museumOwner.update({
      where: {
        email,
      },
      data: {
        token,
      }
    });

    const ownerData = await prisma.museumOwner.findFirst({
      where: {
        email
      },
      select: {
        firstName: true,
        lastName: true,
        token: true,
        museum: {
          select: {
            id: true,
            museumName: true
          }
        }
      }
    }) 

    return res.json({ userData: ownerData });
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: "Internal Server Error" });
  }
};

export const addMuseumDetails = async (req: Request, res: Response) => {
  const { ownerID, inTime, outTime, tags, museumName, aboutMuseum } = req.body;

  try {
    const museumData = await prisma.museumOwner.update({
      where: {
        id: ownerID,
      },
      data: {
        museum: {
          create: {
            museumName,
            aboutMuseum,
            inTime,
            outTime,
            tags,
          },
        },
      },
    });

    // const museumData = await prisma.museum.create({
    //   data: {
    //     onwerID,
    //     museumName,
    //     aboutMuseum,
    //     inTime,
    //     outTime,
    //     tags
    //   }
    // })
    return res.json(museumData);
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: "Internal Server Error" });
  }
};

