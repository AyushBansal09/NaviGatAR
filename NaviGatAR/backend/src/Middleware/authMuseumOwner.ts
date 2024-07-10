import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import "dotenv/config";

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient()

export const verifyTokenMuseumOwner = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
    try {
        const { accessToken } = req.body

        if(!accessToken) throw new Error("No Token!");

        jwt.verify(
            accessToken,
            process.env.JWT_SECRET!,
            async (err: any, value: any) => {
                if(err) {
                    return res.status(401).json({ error: "Unauthenticated" });
                }
                else {
                    const user = await prisma.museumOwner.findUnique({
                        where: {
                            email: value.email
                        }
                    })
                    if (!user) throw new Error("No User!");
                    res.locals.user = user;
                }
            }
        )

        return next()

    } catch (error) {
        return res.status(401).json({ error: "Unauthenticated" });
    }
};
