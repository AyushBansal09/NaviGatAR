/*
  Warnings:

  - You are about to drop the `ARAnchorMatrix` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
DROP TABLE "ARAnchorMatrix";

-- CreateTable
CREATE TABLE "MuseumOwner" (
    "id" TEXT NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "mobileNum" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "organisation" TEXT,

    CONSTRAINT "MuseumOwner_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Museum" (
    "id" TEXT NOT NULL,
    "tags" TEXT[],
    "inTime" TEXT NOT NULL,
    "outTime" TEXT NOT NULL,
    "ARAnchorList" TEXT[],

    CONSTRAINT "Museum_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "MuseumOwner_email_key" ON "MuseumOwner"("email");

-- CreateIndex
CREATE UNIQUE INDEX "MuseumOwner_mobileNum_key" ON "MuseumOwner"("mobileNum");

-- AddForeignKey
ALTER TABLE "Museum" ADD CONSTRAINT "Museum_id_fkey" FOREIGN KEY ("id") REFERENCES "MuseumOwner"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
