-- CreateTable
CREATE TABLE "tourist" (
    "id" TEXT NOT NULL,
    "firstName" TEXT,
    "lastName" TEXT,
    "email" TEXT,
    "mobileNum" TEXT,
    "password" TEXT,

    CONSTRAINT "tourist_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "comments" (
    "id" TEXT NOT NULL,
    "museumID" TEXT,
    "commentBody" TEXT,
    "datePosted" TIMESTAMP(3),

    CONSTRAINT "comments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "tourist_email_key" ON "tourist"("email");

-- CreateIndex
CREATE UNIQUE INDEX "tourist_mobileNum_key" ON "tourist"("mobileNum");

-- AddForeignKey
ALTER TABLE "comments" ADD CONSTRAINT "comments_id_fkey" FOREIGN KEY ("id") REFERENCES "tourist"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
