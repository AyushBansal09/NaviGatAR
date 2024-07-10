/*
  Warnings:

  - A unique constraint covering the columns `[id]` on the table `museum` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateIndex
CREATE UNIQUE INDEX "museum_id_key" ON "museum"("id");
