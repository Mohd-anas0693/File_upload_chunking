import { chunking_backend } from "../../declarations/chunking_backend";
let file;
const uploadChunk = async ({ batch_name, chunk }) => chunking_backend.create_Chunk({
    batch_name,
    content: [...new Uint8Array(await chunk.arrayBuffer())]
})

const upload = async () => {
    if (!file) {
        alert('No file selected');
        return
    }
    console.log('start upload');

    const batch_name = file.name;
    const chunks = [];
    const chunkSize = 1500000;
    for (let start = 0; start < file.size; start += chunkSize) {
        const chunk = file.slice(start, start + chunkSize);
        chunks.push(uploadChunk({
            batch_name,
            chunk,
        }));
    }
    const chunkIds = await Promise.all(chunks);
    console.log(chunkIds);
    console.log(chunkIds.map((chunk) => chunk.chunkId));
    await chunking_backend.commit_batch({
        batch_name,
        chunk_ids: chunkIds.map((chunk) => chunk.chunkId),
        content_type: file.type
    });
    console.log('upload');
    loadImage(batch_name);
};

const loadImage = (batch_name) => {
    if (!batch_name) {
        return;
    }
    const newImage = document.createElement('img');
    newImage.src = `http://127.0.0.1:4943/?canisterId=bd3sg-teaaa-aaaaa-qaaba-cai/assets/${batch_name}`;
    console.log(batch_name);
    const img = document.querySelector('section:last-of-type img');
    img?.parentElement.removeChild(img);

    const section = document.querySelector('input');
    section?.appendChild(newImage);

}
const input = document.querySelector('input');
input?.addEventListener('change', (event) => {
    file = event.target.files?.[0];

});
const btnUpload = document.querySelector('button.upload');
btnUpload?.addEventListener('click', await upload);