Shader "Custom/Leaf"
{
    Properties
    {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags {  "Queue" = "Transparent" "RenderType"="TransparentCutout" }
        // Tags {  "RenderType" = "Opaque"}
        LOD 200
    ZWrite Off
    Blend SrcAlpha OneMinusSrcAlpha 
        Pass{


        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        //#pragma surface surf Standard alpha:fade vertex:vert 
        #pragma vertex vert
        #pragma fragment frag     
        #pragma instancing_options procedural:setup

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 4.0
        #include "UnityCG.cginc"


        sampler2D _MainTex;
        //float4 _MainTex_ST;
       struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float3 normal: NORMAL;
            uint InstanceId           : SV_InstanceID; 
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct Input
        {
            float2 uv: TEXCOORD0;
            float4 vertex: SV_POSITION;
            fixed4 col: COLOR0;
        };

        struct BoidData
		{
			float3 velocity; 
			float3 position;
			float AnimationOffset;
            float3 Color;
            float PiledTime;
            float UpdateTime;
            float Scale;
            int Type;
            float3 NextPos;
            float3 forward;
		};

        float2 random2(float2 st)
        {
            st = float2(dot(st, float2(127.1, 311.7)),
                        dot(st, float2(269.5, 183.3)));
            return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
        }

        float3 random3(float3 st)
        {
            st = float3(dot(st, float3(127.1, 311.7, 599.4)),
                        dot(st, float3(269.5, 183.3, 993.3)),
                        dot(st, float3(392.1, 1830.3, 9937.3))
                        );
            return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
        }
        
		// #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
        StructuredBuffer<BoidData> _BoidDataBuffer;
		// #endif

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        float3 _ObjectScale;
        


		float4x4 eulerAnglesToRotationMatrix(float3 angles)
		{
			float ch = cos(angles.y); float sh = sin(angles.y); // heading
			float ca = cos(angles.z); float sa = sin(angles.z); // attitude
			float cb = cos(angles.x); float sb = sin(angles.x); // bank

			// Ry-Rx-Rz (Yaw Pitch Roll)
			return float4x4(
				ch * ca + sh * sb * sa, -ch * sa + sh * sb * ca, sh * cb, 0,
				cb * sa, cb * ca, -sb, 0,
				-sh * ca + ch * sb * sa, sh * sa + ch * sb * ca, ch * cb, 0,
				0, 0, 0, 1
			);
		}

		Input vert(appdata v)
		{
            Input o;
            // UNITY_SETUP_INSTANCE_ID(v);
            //UNITY_INITIALIZE_OUTPUT(Input, o);
            o.col = fixed4(1,1,1,1);
			// #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
            
            
			BoidData boidData = _BoidDataBuffer[v.InstanceId]; 
            
            o.col.xyz = boidData.Color;
			float3 pos = boidData.position.xyz; 
			float3 scl = float3(boidData.Scale, boidData.Scale, boidData.Scale);  


			float4x4 object2world = (float4x4)0; 
			object2world._11_22_33_44 = float4(scl.xyz, 1.0);
			float rotY = atan2(boidData.forward.x, boidData.forward.z);
			//float rotX = -asin(boidData.velocity.y / (length(boidData.velocity.xyz) + 1e-8));
            
			float4x4 rotMatrix = eulerAnglesToRotationMatrix(float3(0, rotY, 0));




			object2world = mul(rotMatrix, object2world);
			object2world._14_24_34 += pos.xyz;

			v.vertex = mul(object2world, v.vertex);
            

			v.normal = normalize(mul(object2world, v.normal));
            
			// #endif
            o.uv = v.uv;
            o.vertex = v.vertex;
            o.vertex = UnityObjectToClipPos(v.vertex);

            return o;
		}
		
		void setup()
		{
		}

        // // #pragma instancing_options assumeuniformscaling
        // UNITY_INSTANCING_BUFFER_START(Props)
        // // put more per-instance properties here
        // UNITY_INSTANCING_BUFFER_END(Props)


        fixed4 frag (Input IN): SV_Target
        {
            fixed4 c = tex2D (_MainTex, IN.uv);
            float2 uv = IN.uv;
            float3 color = float3(1,1,1);
            //#define UNITY_PROCEDURAL_INSTANCING_ENABLED true
            //#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
            
            color = c.xyz + 0.2*IN.col;
            color *= 0.8;
            
            //#endif
            return fixed4(color.x, color.y, color.z, c.a);

        }

        ENDCG
    }
    }
    // FallBack "Diffuse"
}
