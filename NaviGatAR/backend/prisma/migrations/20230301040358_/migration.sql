-- CreateTable
CREATE TABLE "ARAnchorMatrix" (
    "id" SERIAL NOT NULL,
    "ARAnchorList" TEXT[],

    CONSTRAINT "ARAnchorMatrix_pkey" PRIMARY KEY ("id")
);
