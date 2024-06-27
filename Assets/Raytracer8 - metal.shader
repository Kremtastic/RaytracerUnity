Shader "Unlit/MetalMaterial"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NumSamples("Rays Per Pixel: ", Range(1, 75)) = 16  // Rays Per Pixels (samples)
        _MaxBounces("Max Bounces", Range(0, 30)) = 5  // Bounces

        _PctReflectivity("Reflectivity%", Range(0,1)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #define INFINITY 1e8
            #define MAX_SPHERES 4

		    #pragma vertex vert
		    #pragma fragment frag

		    typedef vector <float, 3> vec3;  // to get more similar code to book
		    typedef vector <fixed, 3> col3;
            typedef vector <float, 4> vec4;

		    //redeclaring ui inputs
		    int _boolchooser;
		    float _floatchooser;
		    float4 _colorchooser; // alternative use fixed4; range of -2.0 to +2.0 and 1/256th precision. (https://docs.unity3d.com/Manual/SL-DataTypesAndPrecision.html)
		    float4 _vec4chooser;
            float _PctReflectivity;
            float _cameraPosX;
            float _cameraPosY;
            float _cameraLookatPos;
            float _moveSpherePosX;
            int _NumSamples;
             int _MaxBounces;

		    //sampler2D _texturechooser;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            struct Sphere {
                float3 center;
                float radius;
            };

            // Define an array of spheres
            static const Sphere spheres[MAX_SPHERES] = {
                {float3( 0.0, -100.5, -1.0), 100.0},  // Ground
                {float3( 0.0,    0.0, -1.0),   0.5},  // Center sphere (Lambertian)
                {float3(-1.0,    0.0, -1.0),   0.5},  // Left sphere (Metallic)
                {float3( 1.0,    0.0, -1.0),   0.5}   // Right sphere (Metallic)
            };


            float hit_sphere(const Sphere sphere, float3 ray_origin, float3 ray_direction, out float3 hit_normal) 
            {
                float3 oc = ray_origin - sphere.center;
                float a = dot(ray_direction, ray_direction);
                float b = dot(oc, ray_direction);
                float c = dot(oc, oc) - sphere.radius * sphere.radius;
                float discriminant = b*b - a*c;
                if (discriminant > 0) {
                    float temp = (-b - sqrt(discriminant)) / a;
                    if (temp > 0.001) {
                        hit_normal = normalize((ray_origin + temp * ray_direction) - sphere.center);
                        return temp;
                    }
                }
                return -1.0;
            }

            float random(float2 uv, int s) {
                float2 seed = float2(dot(uv, float2(12.9898, 78.233)) + s, dot(uv, float2(24.8793, 76.233)) + s);
                seed = frac(sin(seed) * 43758.5453);
                return seed.x + seed.y;
            }


            // Generates a random point inside a unit sphere
            vec3 random_in_unit_sphere(float2 uv, int s) {
                vec3 p;
                do {
                    // Creates a random point in a unit cube and scales it to a unit sphere
                    p = 2.0 * vec3(random(uv, s), random(uv + 1.0, s), random(uv + 2.0, s)) - vec3(1.0, 1.0, 1.0);
                } while (dot(p, p) >= 1.0); // Repeat until the point is inside the unit sphere
                return p;
            }

            vec3 reflect(const vec3 v, const vec3 n) {
                return v - 2.0 * dot(v, n) * n;
            }

            vec3 color(const vec3 ray_origin, const vec3 ray_direction, float2 uv, int s) {
                    vec3 accumulated_color = vec3(0, 0, 0);
                    vec3 current_ray_origin = ray_origin;
                    vec3 current_ray_direction = ray_direction;
                    vec3 attenuation = vec3(1.0, 1.0, 1.0); // Start with full color, attenuate with each bounce
    
                for (int bounce = 0; bounce < _MaxBounces; ++bounce) {
                    float hit_distance = INFINITY;
                    vec3 hit_normal;
                    bool hit_something = false;
                    vec3 albedo = vec3(0.0, 0.0, 0.0);
                    bool is_metallic = false;

                    // Sphere logic
                    int hitSphereIndex = -1; // Initialize to an invalid index
                    for (int j = 0; j < MAX_SPHERES; j++) {
                        float distance = hit_sphere(spheres[j], current_ray_origin, current_ray_direction, hit_normal);

                        if (distance > 0.001f && distance < hit_distance) {
                            hit_distance = distance;
                            hit_something = true;
                            hitSphereIndex = j;
                
                            // Assign colors to spheres
                            if (j == 0) // Ground
                            { 
                                albedo = col3(0.8, 0.8, 0.0);
                            } 
                            else if (j == 1) // Center Sphere
                            { 
                                albedo = col3(0.7, 0.3, 0.3);
                            } 
                            else if (j == 2) // Left Metallic Sphere
                            { 
                                albedo = col3(0.8, 0.8, 0.8);
                                is_metallic = true;
                            }
                            else if (j == 3) // Right Metallic Sphere
                            {
                                albedo = col3(0.8, 0.6, 0.2);
                                is_metallic = true;
                            }
                        }
                    }

                    if (hit_something) {
                        vec3 hit_point = current_ray_origin + hit_distance * current_ray_direction;
                        // Apply fuzziness if a metallic sphere was hit
                        if (hitSphereIndex == 2 || hitSphereIndex == 3) { // Check if the hit sphere is metallic
                            //float fuzziness = hitSphereIndex == 2 ? 0.3f : 1.0f; // Apply different fuzziness based on the sphere
                            float fuzziness = 0.0f; // No fuzzines
                            vec3 reflected_direction = reflect(normalize(current_ray_direction), hit_normal);
                            vec3 fuzz_direction = fuzziness * random_in_unit_sphere(uv, s);
                            current_ray_direction = normalize(reflected_direction + fuzz_direction);

                            attenuation *= albedo * _PctReflectivity;
                        } else {
                            // Lambertian materials
                            vec3 target = hit_point + hit_normal + random_in_unit_sphere(uv, s);
                            current_ray_origin = hit_point + 0.001 * hit_normal;
                            current_ray_direction = normalize(target - current_ray_origin);
                            attenuation *= albedo * _PctReflectivity;
                        }
                    } else {
                        // Apply sky gradient
                        float t = 0.5f * (normalize(current_ray_direction).y + 1.0f);
                        vec3 sky_color = (1.0f - t) * col3(1.0, 1.0, 1.0) + t * col3(0.5, 0.7, 1.0);
                        accumulated_color = sky_color;
                    }
                }
                return accumulated_color * attenuation; // Apply attenuation last to affect overall color
            }


            vec4 frag(v2f i) : SV_TARGET {
                vec3 color_accumulated = col3(0, 0, 0);
                vec3 ray_origin = vec3(1 * _cameraPosX, 1 * _cameraPosY, 0); // Camera origin

                // Antialiasing loop
                for (int s = 0; s < _NumSamples; ++s) {
                    float2 jitter = (random(i.uv * float(s), s) - 0.5) * 2.0 / float(_ScreenParams.y);
                    float2 uv = i.uv * 2.0 - 1.0 + jitter;
                    vec3 ray_direction = normalize(vec3(uv.x * 2, uv.y, -1.0));
                    color_accumulated += color(ray_origin, ray_direction, i.uv, s);
                }

                vec3 final_color = color_accumulated / float(_NumSamples);
                // Convert the accumulated linear color to sRGB space before output
                final_color.r = pow(final_color.r, 1.0 / 2.2);
                final_color.g = pow(final_color.g, 1.0 / 2.2);
                final_color.b = pow(final_color.b, 1.0 / 2.2);

                return vec4(final_color, 1.0);
            }
            ENDCG

       }
    }
}
