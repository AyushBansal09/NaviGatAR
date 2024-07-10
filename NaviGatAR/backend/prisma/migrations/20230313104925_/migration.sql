/*
  Warnings:

  - You are about to drop the `Museum` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `MuseumOwner` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "Museum" DROP CONSTRAINT "Museum_id_fkey";

-- DropTable
DROP TABLE "Museum";

-- DropTable
DROP TABLE "MuseumOwner";

-- CreateTable
CREATE TABLE "museumOwner" (
    "id" TEXT NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "mobileNum" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "organisation" TEXT,

    CONSTRAINT "museumOwner_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "museum" (
    "id" TEXT NOT NULL,
    "tags" TEXT[],
    "inTime" TEXT,
    "outTime" TEXT,
    "ARAnchorList" TEXT[],

    CONSTRAINT "museum_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "museumOwner_email_key" ON "museumOwner"("email");

-- CreateIndex
CREATE UNIQUE INDEX "museumOwner_mobileNum_key" ON "museumOwner"("mobileNum");

-- AddForeignKey
ALTER TABLE "museum" ADD CONSTRAINT "museum_id_fkey" FOREIGN KEY ("id") REFERENCES "museumOwner"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
