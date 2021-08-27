Shader "Custom/Fish"
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
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard vertex:vert addshadow
        #pragma instancing_options procedural:setup

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
            float3 vertex;
            float3 modelVertex;
        };
        struct BoidData
		{
			float3 velocity; 
			float3 position;
			float AnimationOffset;
            float3 Color;
            float Scale;
            int Type;
            float3 forward;
            float2 speeds;
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
        
		#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
			StructuredBuffer<BoidData> _BoidDataBuffer;
		#endif

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        float3 _ObjectScale;
        // float _ime;

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

		void vert(inout appdata_full v, out Input o)
		{
            UNITY_INITIALIZE_OUTPUT(Input, o);
			#ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
            
            o.modelVertex = v.vertex;
			BoidData boidData = _BoidDataBuffer[unity_InstanceID]; 

			float3 pos = boidData.position.xyz; 
			//float tmp = pos.y;
			//pos.y = pos.z;
			//pos.z = tmp;
			float3 scl = float3(boidData.Scale, boidData.Scale, boidData.Scale);  


			float4x4 object2world = (float4x4)0; 
			object2world._11_22_33_44 = float4(scl.xyz, 1.0);
			float rotY = atan2(boidData.forward.x, boidData.forward.z);
			float rotX = -asin(boidData.forward.y / (length(boidData.forward.xyz) + 1e-8));
            
			float4x4 rotMatrix = eulerAnglesToRotationMatrix(float3(rotX, rotY, 0));


            float A = 0.3;
            float alpha = 1.5;
            float k = 2;
            float defaltV = 5;
            float offset = boidData.AnimationOffset*0.1;
            float s = (-v.vertex.z+20)/20;
            float AnimrotY = A*exp(alpha*(s-1)) * sin(k*s - offset + defaltV * _Time.y);
            
            float4x4 rotMatrix2 = eulerAnglesToRotationMatrix(float3(0, AnimrotY, 0));


            object2world = mul(rotMatrix2, object2world);
			object2world = mul(rotMatrix, object2world);
			object2world._14_24_34 += pos.xyz;

			v.vertex = mul(object2world, v.vertex);
            

			v.normal = normalize(mul(object2world, v.normal));
            
			#endif
            o.vertex = v.vertex;
		}
		
		void setup()
		{
		}

        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            #ifdef UNITY_PROCEDURAL_INSTANCING_ENABLED
            
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;

            BoidData boidData = _BoidDataBuffer[unity_InstanceID]; 

			/*
            float2 st = IN.vertex.xz;
            st *= 7;
            float2 ist = floor(st);
            float2 fst = frac(st);
            float distance = 500;
            for (int y = -1; y <= 1; y++)
            for (int x = -1; x <= 1; x++)
            {
                float2 neighbor = float2(x, y);
                float2 p = 0.5 + 0.5 * sin(_Time.y  + 6.2831 * random2(ist + neighbor));
                float2 diff = neighbor + p - fst;
                distance = min(distance, length(diff));
            }

            float3 st3 = IN.modelVertex;
            st3 *= 0.5;
            float3 ist3 = floor(st3);
            float3 fst3 = frac(st3);
            float distance3 = 500;

            for (int z = -1; z <= 1; z++)
            for (int y = -1; y <= 1; y++)
            for (int x = -1; x <= 1; x++)
            {
                float3 neighbor = float3(x, y, z);
                float3 p = 0.5 + 0.5 * sin(6.2831 * random3(ist3 + neighbor));
                float3 diff = neighbor + p - fst3;
                distance3 = min(distance3, length(diff));
            }

            float3 color = float3(1,1,1)*0.5;
            if(distance3 < 0.5 || boidData.Type == 2) {
                float originalRate = 0.5;
                color = normalize(boidData.velocity/2 + 0.5)*(1-originalRate)+boidData.Color*originalRate;
                
                float maxCol = max(color.x, max(color.y, color.z));
                float SatRate = 0.5;
                if(abs(maxCol - color.x) < 0.000001) color.yz *= SatRate;
                else if(abs(maxCol - color.y) < 0.000001) color.xz *= SatRate;
                else color.xy *= SatRate;
                color *= 1.2;
            }
			*/
            o.Albedo = boidData.Color;
			//o.Albedo = float3(0,0,0);
            
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = c.a;

            #endif
        }
        ENDCG
    }
    FallBack "Diffuse"
}
