-- DropForeignKey
ALTER TABLE "comments" DROP CONSTRAINT "comments_id_fkey";

-- AlterTable
ALTER TABLE "comments" ADD COLUMN     "touristID" TEXT;

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_touristID_fkey" FOREIGN KEY ("touristID") REFERENCES "tourist"("id") ON DELETE SET NULL ON UPDATE CASCADE;
