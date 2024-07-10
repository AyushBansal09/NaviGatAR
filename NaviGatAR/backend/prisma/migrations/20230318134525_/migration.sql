/*
  Warnings:

  - A unique constraint covering the columns `[onwerID]` on the table `museum` will be added. If there are existing duplicate values, this will fail.

*/
-- DropForeignKey
ALTER TABLE "museum" DROP CONSTRAINT "museum_id_fkey";

-- AlterTable
ALTER TABLE "museum" ADD COLUMN     "onwerID" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "museum_onwerID_key" ON "museum"("onwerID");

-- AddForeignKey
ALTER TABLE "museum" ADD CONSTRAINT "museum_onwerID_fkey" FOREIGN KEY ("onwerID") REFERENCES "museumOwner"("id") ON DELETE SET NULL ON UPDATE CASCADE;
