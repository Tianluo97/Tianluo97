uniform float time;
varying vec2 vUv;
varying vec3 vPosition;
varying vec3 color1;
varying vec3 color2;
uniform vec3 uColor[5];
varying vec3 vColor;
uniform vec2 pixels;
float PI = 3.141592653589793238;

//**********生成基本的noise**********//
//	Simplex 3D Noise 
//	by Ian McEwan, Ashima Arts
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float snoise(vec3 v){ 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //  x0 = x0 - 0. + 0.0 * C 
  vec3 x1 = x0 - i1 + 1.0 * C.xxx;
  vec3 x2 = x0 - i2 + 2.0 * C.xxx;
  vec3 x3 = x0 - 1. + 3.0 * C.xxx;

// Permutations
  i = mod(i, 289.0 ); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients
// ( N*N points uniformly over a square, mapped onto an octahedron.)
  float n_ = 1.0/7.0; // N=7
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z *ns.z);  //  mod(p,N*N)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

// Mix final noise value
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                dot(p2,x2), dot(p3,x3) ) );
}


//**********通过noise的操作变换实现对顶点与颜色的变换**********//
void main() {
  
  //对于noise贴图在横向或纵向上进行uv的调整，确定横向纵向上uv的变化以及波峰的密集程度
  vec2 noiseCoord = uv * vec2(3, 4);

  //叠加了第二张noise的贴图，可以控制横向或纵向上添加大体积的波峰或小体积的波峰 (uv乘的数越大贴图压缩得越小)
  vec2 noiseCoord2 = uv * vec2(.9,1.2);

  //拉长了y方向的值，使得面板进行倾斜，使之使得流动会更加偏向竖向感
  float tilt = -1.8 * uv.y;

  //拉伸贴图x方向的值，面板向x 倾斜 使得流动会具有横向感
  float incline  = uv.x * 0.1;
  
  //再添加了一个offset的值，整体调整一下倾斜角度，进行了一个distort
  float offset = incline * mix(-.25,0.25,uv.y);

  //生成第一张noise的贴图，以便对noise进行z方向的调整; noiseCoord.x/noiseCoord.y + time * 3.会控制贴图整体x或y方向的流速
  //第三个参数time*5. 控制的是整体波动的速度
  float noise = snoise(vec3(noiseCoord.x + time * 20., noiseCoord.y, time * 3.));
  noise = max(0.,noise);

  //生成第二张noise的贴图，以便对noise进行z方向的调整
  float noise2 = snoise(vec3(noiseCoord2.x + time * 2., noiseCoord2.y, time * 5.));
  noise2 = max(0.,noise2);

  //对于position.z进行改变，0.3改变的是noise被拉起来的高度大小
  vec3 pos = vec3(position.x,position.y,position.z + noise * 0.3 + tilt + incline + offset );


  //**********通过noise的操作变换实现对颜色的变换**********//
  vColor = uColor[4];

  for(int i = 0; i < 4; i++) {

    //调整横向flow的速度
    float noiseFlow  = 2. + float(i)*0.3;
    //调整整体color变化的速度
    float noiseSpeed  = 3. + float(i)*0.3;
    float noiseSeed = 1. + float(i)*5.;
  
    //改变x或y的贴图
    vec2 noiseFreq = vec2(1.,1.4)*.6;
    //？？？
    float noiseFloor = 0.1;
    float noiseCeil = 0.6 + float(i)*0.07;

    float colorNoise = smoothstep(noiseFloor,noiseCeil,
      snoise(
        vec3(
          noiseCoord.x * noiseFreq.x + time * noiseFlow,
          noiseCoord.y * noiseFreq.y, 
          time * noiseSpeed + noiseSeed
        )
      ) 
    );

    float colorNoise2 =
      snoise(
        vec3(
          noiseCoord.x * noiseFreq.x + time * noiseFlow,
          noiseCoord.y * noiseFreq.y, 
          time * noiseSpeed + noiseSeed
        )
      ) ; 

      colorNoise2 = max(0.,colorNoise2);
    

    
    vColor = mix(vColor,uColor[i],colorNoise);
    //vColor = mix(color1,color2,colorNoise2);
  }

  //进行uv的转化
  vUv = uv;
  //进行坐标系的转化
  gl_Position = projectionMatrix * modelViewMatrix * vec4( pos, 1.0 );
}