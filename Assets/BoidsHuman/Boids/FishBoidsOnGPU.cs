using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;


namespace FishBoidsOnGPU
{
    public class FishBoidsOnGPU : MonoBehaviour
    {
        [System.Serializable]
        struct FishBoidData
        {
            public Vector3 Velocity;
            public Vector3 Position;
            public float AnimationOffset;
            public Vector3 Color;
            public float Scale;
            public int Type;
            public Vector3 forward;
            public Vector2 speeds;
            public int neib;
        }
        struct MeshVertData
        {
            public Vector3 positoin;
            public Vector3 normal;

        }
        struct ForceData
        {
            public Vector3 force;
            public Vector3Int nearests;
            public Vector3 nearP;
            public Vector3 col;
            public int neib;
            public Vector3 prevE;
        }

        const int SIMULATION_BLOCK_SIZE = 256;
        public float scl = 10f;
        public SkinnedMeshRenderer skin;
        protected Mesh mesh;
        private ComputeBuffer _buff;
        private int[] _p;
        private Xorshift _xorshift;
        public Transform Sphere;
        public int mode = 0;
        public bool debug;
        public float Scale = 5;

        #region Boids Parameters
        [Range(0, 15000)]
            public int LargeObjectNum = 1;

            [Range(0, 150000)]
            public int MidiumObjectNum = 20;

            [Range(0, 15000)]
            public int SmallObjectNum = 4000;

            int ObjectNum;

            float[] Scales = new float[3]{0.5f, 0.05f, 0.005f};
            float[,] Speeds = new float[3,2];

            public float CohesionNeighborhoodRadius = 2.0f;
            public float AlignmentNeighborhoodRadius = 2.0f;
            public float SeparateNeighborhoodRadius = 1.0f;

            public float MaxSpeed = 5.0f;
            public float MaxSteerForce = 0.5f;

            public float CohesionWeight = 1.0f;
            public float AlignmentWeight = 1.0f;
            public float SeparateWeight = 3.0f;
            public float InsideMeshWeight = 1000000;
            public float CurlWeight= 20;
            public float VertexFollowWeight= 10000;
            public float TriangleFollowWeight= 5;
            public float AvoidObjectsWeight= 5000;

            public float AvoidWallWeight = 10.0f;

            public Vector3 WallCenter = Vector3.zero;

            public Vector3 WallSize = new Vector3(32.0f, 32.0f, 32.0f);
        #endregion

        #region Built-in Resources
            public ComputeShader FishBoidsCS;
        #endregion

        #region Private Resources
            GraphicsBuffer _boidDataBuffer;        
            GraphicsBuffer _boidForceBuffer;
            ComputeBuffer vertBuffer;
            ComputeBuffer vertBuffer_n;
        #endregion

        #region Rendering Resources
        public Mesh InstanceMesh;
            public Material InstanceRenderMaterial;
        #endregion 

        #region Private Variables
            uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
            GraphicsBuffer argsBuffer;
        #endregion 

        void InitFace()
        {

        }
        private int[] CreateGrid()
        {
            int[] p = new int[256];
            for (int i = 0; i < p.Length; i++)
            {
                p[i] = (int)Mathf.Floor(_xorshift.Random() * 256);
            }

            int[] p2 = new int[512];
            for (int i = 0; i < p2.Length; i++)
            {
                p2[i] = p[i & 255];
            }

            return p2;
        }



        #region MonoBehaviour Functions
        void Start()
            {
                mesh = new Mesh();
                _xorshift = new Xorshift((uint)10);
                _p = CreateGrid();
                ObjectNum = LargeObjectNum + MidiumObjectNum + SmallObjectNum;
                Speeds[0,0] = 0.5f; Speeds[0,1] = 1.0f;
                Speeds[1,0] = 0.5f; Speeds[1,1] = 100f;
                Speeds[2,0] = 0.5f; Speeds[2,1] = 1.0f;
                InitFace();
                InitGraphicsBuffer();
                InitRenderBuffer();
                skin.BakeMesh(mesh);
                var vertices = mesh.vertices;
                vertBuffer = new ComputeBuffer(vertices.Length, Marshal.SizeOf(typeof(Vector3)));
                vertBuffer_n = new ComputeBuffer(vertices.Length, Marshal.SizeOf(typeof(Vector3)));
        }

            // Update is called once per frame
            void Update()
            {
                Simulation();
                RenderInstancedMesh();
                if (Input.GetKeyDown(KeyCode.Space))
                {
                    mode = (mode + 1) % 2;
                }
            }
            void OnDestroy()
            {
                ReleaseBuffer();
            }

            void OnDisable()
            {
                if (argsBuffer != null)
                    argsBuffer.Release();
                argsBuffer = null;
            }
            void OnDrawGizmos()
            {
                // デバッグとしてシミュレーション領域をワイヤーフレームで描画
                Gizmos.color = Color.cyan;
                Gizmos.DrawWireCube(WallCenter, WallSize);
            }
        #endregion


        #region Private Functions
            int ItrToType(int itr){
                if(itr < LargeObjectNum) return 0;
                else if(itr < LargeObjectNum + MidiumObjectNum) return 1;
                else return 2;
            }

            void InitGraphicsBuffer()
            {
                var type = GraphicsBuffer.Target.Index | GraphicsBuffer.Target.Structured;
                _boidDataBuffer = new GraphicsBuffer(
                    GraphicsBuffer.Target.Structured, ObjectNum, Marshal.SizeOf(typeof(FishBoidData))
                );
                _boidForceBuffer = new GraphicsBuffer(
                    GraphicsBuffer.Target.Structured, ObjectNum, Marshal.SizeOf(typeof(ForceData))
                );

                var forceArr = new ForceData[ObjectNum];
                var boidDataArr = new FishBoidData[ObjectNum];
                for (var i = 0; i < ObjectNum; i++)
                {
                    forceArr[i].force = Vector3.zero;
                    forceArr[i].prevE = Vector3.zero;
                    forceArr[i].neib= 0;
                    forceArr[i].nearests = Vector3Int.zero;
                    forceArr[i].nearP = Vector3.zero;
                    forceArr[i].col = boidDataArr[i].Color = Random.insideUnitSphere * 0.5f + new Vector3(0.5f, 0.5f, 0.5f);
                    boidDataArr[i].Position = Random.insideUnitSphere * 10.0f;
                    boidDataArr[i].Velocity = Random.insideUnitSphere * 0.1f;
                    boidDataArr[i].forward = boidDataArr[i].Velocity * 10;
                    boidDataArr[i].AnimationOffset = 0.0f;
                    boidDataArr[i].speeds = new Vector2(Speeds[ItrToType(i), 0], MaxSpeed);
                    boidDataArr[i].Color = Random.insideUnitSphere * 1.0f;
                    boidDataArr[i].Scale = Scale;
                    boidDataArr[i].Type = ItrToType(i);
                    boidDataArr[i].neib = 0;
            }
                _boidDataBuffer.SetData(boidDataArr);
                _boidForceBuffer.SetData(forceArr);
                
                forceArr = null;
                boidDataArr = null;
            }

            void InitRenderBuffer(){
                argsBuffer = new GraphicsBuffer(
                    GraphicsBuffer.Target.IndirectArguments,
                    1, args.Length * sizeof(uint));
            }


            void Simulation()
            {
                ComputeShader cs = FishBoidsCS;
                int id = -1;

                int threadGroupSize = Mathf.CeilToInt((float)ObjectNum / (float)SIMULATION_BLOCK_SIZE);

                skin.BakeMesh(mesh);
                var vertices = mesh.vertices;
                var normals = mesh.normals;
                var vertBuffer = new ComputeBuffer(vertices.Length, Marshal.SizeOf(typeof(Vector3)));
                vertBuffer.SetData(vertices);
                var vertBuffer_n = new ComputeBuffer(normals.Length, Marshal.SizeOf(typeof(Vector3)));
                vertBuffer_n.SetData(normals);
                var meshBuffer = new ComputeBuffer(vertices.Length, Marshal.SizeOf(typeof(MeshVertData)));
                MeshVertData[] meshVertdata = new MeshVertData[vertices.Length];
                for(int i=0; i<vertices.Length; i++)
                {
                    meshVertdata[i].positoin = vertices[i]*scl;
                    meshVertdata[i].normal = normals[i];

                }
                meshBuffer.SetData(meshVertdata);
                


            if (_buff == null)
                {
                    _buff = new ComputeBuffer(512, sizeof(int));
                    _buff.SetData(_p);
                }
                //
                id = cs.FindKernel("ForceCS"); 
                cs.SetInt("_MaxBoidObjectNum", ObjectNum);
                cs.SetInt("_MaxVertObjectNum", vertices.Length);
                cs.SetFloat("_CohesionNeighborhoodRadius", CohesionNeighborhoodRadius);
                cs.SetFloat("_AlignmentNeighborhoodRadius", AlignmentNeighborhoodRadius);
                cs.SetFloat("_SeparateNeighborhoodRadius", SeparateNeighborhoodRadius);
                cs.SetFloat("_MaxSpeed", MaxSpeed);
                cs.SetFloat("_MaxSteerForce", MaxSteerForce);
                cs.SetFloat("_SeparateWeight", SeparateWeight);
                cs.SetFloat("_CohesionWeight", CohesionWeight);
                cs.SetFloat("_AlignmentWeight", AlignmentWeight);
                cs.SetVector("_WallCenter", WallCenter);
                cs.SetVector("_WallSize", WallSize);
                cs.SetInt("_mode", mode);
                cs.SetBool("_debug", debug);
                cs.SetVector("Sphere", Sphere.position);
            
                cs.SetFloat("_InsideMeshWeight", InsideMeshWeight);
                cs.SetFloat("_CurlWeight", CurlWeight);
                cs.SetFloat("_VertexFollowWeight", VertexFollowWeight);
                cs.SetFloat("_TriangleFollowWeight", TriangleFollowWeight);
                cs.SetFloat("_AvoidObjectsWeight", AvoidObjectsWeight);

                cs.SetFloat("_DrawScale",Scale);   

            cs.SetFloat("_DeltaTime", Time.deltaTime);
                cs.SetFloat("_AvoidWallWeight", AvoidWallWeight);
                 cs.SetBuffer(id, "_MeshBuffer", meshBuffer);
                cs.SetBuffer(id, "_BoidDataBufferRead", _boidDataBuffer);
                cs.SetBuffer(id, "_BoidForceBufferWrite", _boidForceBuffer);

                float[] _noiseScales = new[] { 0.4f, 0.23f, 0.11f, };
                cs.SetFloats("_NoiseScales", _noiseScales);

                int octaves = Mathf.Clamp(1, 1, 16);
                cs.SetInt("_Octaves", octaves);
                float frequency = Mathf.Clamp(1.0f, 0.1f, 64.0f);
                cs.SetFloat("_Frequency", frequency);

                cs.SetBuffer(id, "_P", _buff);
                cs.Dispatch(id, threadGroupSize, 1, 1); 
                //
                id = cs.FindKernel("IntegrateCS");
                cs.SetInt("_MaxVertObjectNum", vertices.Length);
                cs.SetFloat("_DeltaTime", Time.deltaTime);
                cs.SetFloat("_Time", Time.time);
                cs.SetInt("_mode", mode);
                cs.SetBuffer(id, "_BoidForceBufferRead", _boidForceBuffer);
                cs.SetBuffer(id, "_BoidDataBufferWrite", _boidDataBuffer);


                cs.Dispatch(id, threadGroupSize, 1, 1); 
            }
            void RenderInstancedMesh(){

                if (InstanceRenderMaterial == null ||
                    !SystemInfo.supportsInstancing){
                        Debug.Log("Failed");
                    return;
                }


                uint numIndices = (InstanceMesh != null) ?
                    (uint)InstanceMesh.GetIndexCount(0) : 0;
                args[0] = (uint)numIndices; 
                args[1] = (uint)ObjectNum; 

                argsBuffer.SetData(args); 

                InstanceRenderMaterial.SetBuffer("_BoidDataBuffer",_boidDataBuffer);

                

                var bounds = new Bounds
                (
                    WallCenter,
                    WallSize
                );

                Graphics.DrawMeshInstancedIndirect
                (
                    InstanceMesh,          
                    0,                      
                    InstanceRenderMaterial, 
                    bounds,                 
                    argsBuffer             
                );
                
            }

          
            void ReleaseBuffer()
            {
                if (_boidDataBuffer != null)
                {
                    _boidDataBuffer.Release();
                    _boidDataBuffer = null;
                }

                if (_boidForceBuffer != null)
                {
                    _boidForceBuffer.Release();
                    _boidForceBuffer = null;
                }

                if (vertBuffer != null)
                {
                    vertBuffer.Release();
                    vertBuffer = null;
                }
        }
        #endregion
    }
}
