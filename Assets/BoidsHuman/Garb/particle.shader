Shader "Unlit/particle"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent"  "Queue" = "Transparent"}
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha 

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma instancing_options procedural:setup
            

            #include "UnityCG.cginc"
            

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                uint InstanceId           : SV_InstanceID;
                float3 normal : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID 
            };

            struct ParticleData
            {
                float3 position;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 normal: TEXCOORD2;
                float3 viewDir: TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            StructuredBuffer<ParticleData> _particleDataBuffer;
            v2f vert (appdata v)
            {
                v2f o;
                float scale = 0.1;
                float3 scl = float3(scale, scale, scale);
                ParticleData particleData = _particleDataBuffer[v.InstanceId];
                float4x4 object2world = (float4x4)0;  
                float3 pos = particleData.position.xyz; 
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                object2world._11_22_33_44 = float4(scl.xyz, 1.0);
                object2world._14_24_34 += pos.xyz;
                v.vertex = mul(object2world, v.vertex);
                o.vertex = UnityObjectToClipPos(v.vertex);
                
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.viewDir = normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, v.vertex).xyz);
                o.normal =  normalize(mul(v.normal, unity_ObjectToWorld).xyz);
                return o;
            }
            void setup()
            {
            }
            fixed4 frag (v2f i) : SV_Target
            {
                i.viewDir = normalize(i.viewDir);

                fixed4 col = tex2D(_MainTex, i.uv);

                half rim = abs(dot(i.normal, i.viewDir));
                rim = pow(rim, 3);
                col.a *= rim;
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
